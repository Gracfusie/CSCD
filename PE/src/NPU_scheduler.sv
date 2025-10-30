module npu_scheduler #(
  parameter int W_IN   = 8,
  parameter int MUX_WIDTH = 4
) (
  input  logic                    clk,          // work clock
  input  logic                    reset,        // async, high-active
  input  logic         [W_IN-1:0] instr,        // input1 (treated as unsigned)

  output logic                    pe_en,       // enable signal
  output logic                    pe_mode_sel, // mode select Relu, normal
  output logic                    pe_reg_reset,  // reg reset
  output logic         [MUX_WIDTH-1:0] pe_mux_sel    // output instruction
  output logic         []

);



endmodule