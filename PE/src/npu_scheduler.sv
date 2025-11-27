module npu_scheduler #(
  parameter int N = 10,
  parameter int K_SIZE = 3,
  parameter int W_IN = 8,
  parameter int ADDR_W = 3,
  parameter int SEL_DEMUX_WIDTH = 6,
  parameter int SEL_MUX_A_WIDTH = 4,
  parameter int SEL_MUX_B_WIDTH = 5
) (
  input  logic                        clk,          // work clock
  input  logic                        rst_n,        // async, high-active
  input  logic                  [3:0] wen_i,        // write enable
  input  logic             [W_IN-1:0] instr,        // input1 (treated as unsigned)
  input  logic           [ADDR_W-1:0] addr,

  output logic                        wen,    // buffer write enable
  output logic                        pe_en,         // enable signal
  output logic                        pe_mode_sel,   // mode select Relu, normal
  output logic                        pe_reg_reset,  // reg reset
  output logic  [SEL_DEMUX_WIDTH-1:0] pe_demux_sel,  // output instruction
  output logic  [SEL_MUX_A_WIDTH-1:0] pe_mux_a_sel,  // MUX A select
  output logic  [SEL_MUX_B_WIDTH-1:0] pe_mux_b_sel,   // MUX B select
  output logic                  [1:0] write_back_mode   // write back mode
);

// Decode instructions to control signals

logic        layer_select_en;
logic        reuse;
logic  [1:0] load_mode;

always_comb begin
  layer_select_en = instr[7];
  reuse           = (~instr[7]) & instr[6];
  load_mode       = {2{~instr[7]}} & instr[1:0];
end

logic        reg_reset_en;
logic        relu_broadcast_en;
logic  [3:0] line_count;
logic        buffer_a_mode;

always_ff @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    reg_reset_en      <= 1'b0;
    relu_broadcast_en <= 1'b0;
    line_count        <= 4'b0;
    write_back_mode   <= 2'b00;
    buffer_a_mode     <= 1'b0;
  end else if (wen_i[3]) begin
    if (layer_select_en) begin
      reg_reset_en      <= instr[6];
      relu_broadcast_en <= instr[5];
      buffer_a_mode     <= instr[4];
      line_count        <= instr[3:0];
    end else if (instr[3:2] != 2'b00) begin
      write_back_mode <= instr[3:2];
    end
  end
end

// LOAD control signals

parameter LOAD_IDLE      = 0;
parameter LOAD_A         = 1;
parameter LOAD_B         = 2;
parameter LOAD_C         = 3;
parameter BUFFER_A_DEPTH = N*K_SIZE;                          // 30
parameter BUFFER_B_DEPTH = N*K_SIZE;                          // 30
parameter BUFFER_C_DEPTH = K_SIZE;                            // 3
parameter BUFFER_A_START = 0;                                 // 0
parameter BUFFER_B_START = BUFFER_A_START + BUFFER_A_DEPTH;   // 30
parameter BUFFER_C_START = BUFFER_B_START + BUFFER_B_DEPTH;   // 60
parameter BUFFER_A_WIDTH = $clog2(BUFFER_A_DEPTH);
parameter BUFFER_B_WIDTH = $clog2(BUFFER_B_DEPTH);
parameter BUFFER_C_WIDTH = $clog2(BUFFER_C_DEPTH);
logic [BUFFER_A_WIDTH-1:0] buffer_a_ptr;
logic [BUFFER_B_WIDTH-1:0] buffer_b_ptr;
logic [BUFFER_C_WIDTH-1:0] buffer_c_ptr;
logic [1:0] load_b_start;

always_ff @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    buffer_a_ptr <= '0;
    buffer_b_ptr <= '0;
    buffer_c_ptr <= '0;
    load_b_start <= 2'b01;
  end else if (layer_select_en) begin
    buffer_a_ptr <= '0;
    buffer_b_ptr <= '0;
    buffer_c_ptr <= '0;
    load_b_start <= 2'b01;
  end else begin
    case (load_mode)
      LOAD_A: begin
        if (buffer_a_mode) begin
          buffer_a_ptr <= (buffer_a_ptr < K_SIZE - 1) ? buffer_a_ptr + 1 : 0;
        end else begin
          buffer_a_ptr <= (buffer_a_ptr < BUFFER_A_DEPTH - 1) ? buffer_a_ptr + 1 : 0;
        end
      end
      LOAD_B: begin
        if (buffer_b_ptr < BUFFER_B_DEPTH - K_SIZE) begin
          buffer_b_ptr <= buffer_b_ptr + K_SIZE;
        end else begin
          buffer_b_ptr <= load_b_start;
          load_b_start <= (load_b_start < K_SIZE - 1) ? load_b_start + 1 : 0;
        end
      end
      LOAD_C: begin
        buffer_c_ptr <= (buffer_c_ptr < BUFFER_C_DEPTH - 1) ? buffer_c_ptr + 1 : 0;
      end
      default: begin
        buffer_a_ptr <= buffer_a_ptr;
        buffer_b_ptr <= buffer_b_ptr;
        buffer_c_ptr <= buffer_c_ptr;
      end
    endcase
  end
end

// Output logic based on state
always_comb begin
  case(load_mode)
    LOAD_A: begin
      wen = 1'b1;
      pe_demux_sel = BUFFER_A_START + buffer_a_ptr;
    end
    LOAD_B: begin
      wen = 1'b1;
      pe_demux_sel = BUFFER_B_START + buffer_b_ptr;
    end
    LOAD_C: begin
      wen = 1'b1;
      pe_demux_sel = BUFFER_C_START + buffer_c_ptr;
    end
    default: begin
      wen = 1'b0;
      pe_demux_sel = '0;
    end
  endcase
end

// COMPUTE control signals

logic [SEL_MUX_A_WIDTH-1:0] data_counter;
logic                 [3:0] subimage_counter;
logic                       compute_en;

assign compute_en = data_counter > 0;


logic [SEL_MUX_A_WIDTH-1:0] image_ptr;
logic [1:0] block_head; 
logic new_subimage;

always_ff @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    data_counter     <= '0;
    image_ptr        <= '0;
    block_head       <= '0;
    new_subimage     <= 1'b0;
    subimage_counter <= '0;
  end else if (layer_select_en) begin
    data_counter     <= '0;
    image_ptr        <= '0;
    block_head       <= '0;
    new_subimage     <= 1'b0;
    subimage_counter <= '0;
  end else begin
    if (compute_en) begin
      if (((load_mode == LOAD_B) && (buffer_b_ptr >= BUFFER_B_DEPTH - K_SIZE)) || (load_mode == LOAD_C)) begin
        if (reuse) begin
          data_counter <= data_counter + K_SIZE*K_SIZE - 1;
        end else begin
          data_counter <= data_counter + K_SIZE - 1;
        end
      end else begin
        data_counter <= data_counter - 1;
      end
      image_ptr <= (image_ptr < (K_SIZE*K_SIZE-1)) ? image_ptr + 1 : 0;
      if (image_ptr == (K_SIZE*K_SIZE-1)) begin
        new_subimage <= 1'b1;
        block_head <= (block_head < (K_SIZE-1)) ? block_head + 1 : 0;
      end else begin
        new_subimage <= 1'b0;
      end
    end else begin
      if (new_subimage == 1'b1) begin
        subimage_counter <= (subimage_counter < line_count - 1) ? subimage_counter + 1 : 0;
        if (subimage_counter == line_count - 1) begin
          block_head <= (block_head > 0) ? block_head - 1 : K_SIZE - 1;
        end
        new_subimage <= 1'b0;
      end else if (load_mode == LOAD_A) begin
        subimage_counter <= '0;
        block_head <= '0;
      end
      if (((load_mode == LOAD_B) && (buffer_b_ptr >= BUFFER_B_DEPTH - K_SIZE)) || (load_mode == LOAD_C)) begin
        if (reuse) begin
          data_counter <= K_SIZE*K_SIZE;
        end else begin
          data_counter <= K_SIZE;
        end
      end
    end
  end
end

// Output logic based on state
always_comb begin
  pe_en         = compute_en;
  pe_mode_sel   = relu_broadcast_en;
  pe_reg_reset  = (reg_reset_en & new_subimage) | layer_select_en;
  pe_mux_a_sel  = image_ptr;
  pe_mux_b_sel  = (image_ptr + block_head*K_SIZE) % (K_SIZE*K_SIZE) + (relu_broadcast_en ? K_SIZE*K_SIZE : 0);
end

endmodule