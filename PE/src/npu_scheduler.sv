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
  input  logic             [W_IN-1:0] instr,        // input1 (treated as unsigned)
  input  logic           [ADDR_W-1:0] addr,

  output logic                        wen,    // buffer write enable
  output logic                [N-1:0] pe_en,         // enable signal
  output logic                [N-1:0] pe_mode_sel,   // mode select Relu, normal
  output logic                [N-1:0] pe_reg_reset,  // reg reset
  output logic  [SEL_DEMUX_WIDTH-1:0] pe_demux_sel,  // output instruction
  output logic  [SEL_MUX_A_WIDTH-1:0] pe_mux_a_sel,  // MUX A select
  output logic  [SEL_MUX_B_WIDTH-1:0] pe_mux_b_sel   // MUX B select
);

// Decode instructions to control signals

logic       start_load;

// LOAD control signals

parameter LOAD_IDLE = 0;
parameter LOAD_A    = 1;
parameter LOAD_B    = 2;
parameter LOAD_C    = 3;
logic [1:0] load_mode;

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

always_ff @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    buffer_a_ptr <= '0;
    buffer_b_ptr <= '0;
    buffer_c_ptr <= '0;
  end else begin
    case (load_mode)
      LOAD_A: begin
        buffer_a_ptr <= (buffer_a_ptr < BUFFER_A_DEPTH - 1) ? buffer_a_ptr + 1 : 0;
      end
      LOAD_B: begin
        buffer_b_ptr <= (buffer_b_ptr < BUFFER_B_DEPTH - 1) ? buffer_b_ptr + 1 : 0;
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

// Decode instructions to control signals

logic       compute_en;
logic       broadcast_en;
logic       relu_en;

// Define FSM states
parameter IDLE       = 2'b00;
parameter COMPUTE    = 2'b10;
parameter WRITE_BACK = 2'b11;
logic [1:0] state;

logic [SEL_MUX_A_WIDTH-1:0] image_ptr;
logic [1:0] block_head; 

logic new_subimage;


always_ff @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    state        <= IDLE;
    image_ptr    <= '0;
    block_head   <= '0;
    new_subimage <= 1'b0;
  end else begin
    case (state)
      IDLE: begin
        if (compute_en) begin
          state <= COMPUTE;
        end else begin
          state <= IDLE;
          image_ptr <= '0;
          block_head <= '0;
          new_subimage <= 1'b0;
        end
      end
      COMPUTE: begin
        if (compute_en) begin
          image_ptr <= (image_ptr < (K_SIZE*K_SIZE-1)) ? image_ptr + 1 : 0;
          if (image_ptr == (K_SIZE*K_SIZE-1)) begin
            new_subimage <= 1'b1;
            block_head <= (block_head < (K_SIZE-1)) ? block_head + 1 : 0;
          end else begin
            new_subimage <= 1'b0;
          end
        end
      end
      WRITE_BACK: begin
        
      end
      default: begin
        
      end
    endcase
  end
end


// Output logic based on state
always_comb begin
  // Default values
  pe_en         = '0;
  pe_mode_sel   = '0;
  pe_reg_reset  = '0;
  pe_mux_a_sel  = '0;
  pe_mux_b_sel  = '0;

  case (state)
    COMPUTE: begin
      pe_en         = {N{compute_en}}; // Enable all PEs during compute
      pe_reg_reset  = {N{new_subimage}}; // Reset registers for new sub-image
      pe_mode_sel   = {N{relu_en}}; // Mode select from instruction
      pe_mux_a_sel  = (image_ptr + block_head*K_SIZE) % (K_SIZE*K_SIZE);
      pe_mux_b_sel  = pe_mux_a_sel + (broadcast_en ? K_SIZE*K_SIZE : 0);
    end
    WRITE_BACK: begin
      pe_en         = {N{1'b0}}; // Disable all PEs during write back
    end
    default: begin
      // Do nothing in IDLE state
    end
  endcase
end

endmodule