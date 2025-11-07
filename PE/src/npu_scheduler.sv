module npu_scheduler #(
  parameter int N = 10,
  parameter int W_IN = 8,
  parameter int SEL_DEMUX_WIDTH = 6,
  parameter int SEL_MUX_A_WIDTH = 4,
  parameter int SEL_MUX_B_WIDTH = 5,
  parameter int K_SIZE = 3
) (
  input  logic                        clk,          // work clock
  input  logic                        rst_n,        // async, high-active
  input  logic             [W_IN-1:0] instr,        // input1 (treated as unsigned)

  output logic                [N-1:0] pe_en,         // enable signal
  output logic                [N-1:0] pe_mode_sel,   // mode select Relu, normal
  output logic                [N-1:0] pe_reg_reset,  // reg reset
  output logic  [SEL_DEMUX_WIDTH-1:0] pe_demux_sel,  // output instruction
  output logic  [SEL_MUX_A_WIDTH-1:0] pe_mux_a_sel,  // MUX A select
  output logic  [SEL_MUX_B_WIDTH-1:0] pe_mux_b_sel   // MUX B select
);

// Decode instructions to control signals
logic start;



// Define FSM states
parameter IDLE       = 2'b00;
parameter LOAD       = 2'b01;
parameter COMPUTE    = 2'b10;
parameter WRITE_BACK = 2'b11;
logic [1:0] current_state, next_state;

logic [SEL_MUX_A_WIDTH - 1:0] image_ptr;
logic [1:0] block_head; 
logic [SEL_MUX_A_WIDTH - 1:0] byte_ptr; //真实的memory相对地址

logic new_subimage;

// State transition
always_ff @(posedge clk or negedge rst_n) begin
  if (!rst_n)
    current_state <= IDLE;
  else
    current_state <= next_state;
end

// Next state logic
always_comb begin
  case (current_state)
    IDLE:       
      next_state = start ? LOAD : IDLE;
    LOAD:       
      next_state = COMPUTE;
    COMPUTE:    
      next_state = WRITE_BACK;
    WRITE_BACK: 
      next_state = IDLE;
    default:    
      next_state = IDLE;
  endcase
end

int i;
always_ff @(posedge clk or negedge rst_n) begin
  case (current_state)
    LOAD: begin
      
    end
    COMPUTE: begin
      // a
      for (i = 0; i < N; i = i + 1) begin
        image_ptr <= (image_ptr < 8) ? image_ptr + 1 : 0;
        if (new_subimage) begin
          block_head <= (block_head < 2) ? block_head + 1 : 0;
        end
        byte_ptr <= (image_ptr + block_head*K_SIZE) % 9;
      end
    end
    WRITE_BACK: begin
      
    end
    default: 
  endcase
end




// Output logic based on state
always_comb begin
  // Default values
  pe_en         = '0;
  pe_mode_sel   = '0;
  pe_reg_reset  = '0;
  pe_demux_sel  = '0;
  pe_mux_a_sel  = '0;
  pe_mux_b_sel  = '0;

  case (current_state)
    LOAD: begin
      pe_en         = {N{1'b1}}; // Enable all PEs during load
      pe_reg_reset  = {N{1'b1}}; // Reset registers during load
      pe_demux_sel  = instr[SEL_DEMUX_WIDTH-1:0];
    end
    COMPUTE: begin
      pe_en         = {N{1'b1}}; // Enable all PEs during compute
      pe_mode_sel   = instr[SEL_MUX_A_WIDTH +: N]; // Mode select from instruction
      pe_mux_a_sel  = byte_ptr;
      pe_mux_b_sel  = instr[SEL_MUX_B_WIDTH-1:0];
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