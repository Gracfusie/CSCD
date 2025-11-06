module npu_scheduler #(
  parameter int N = 10,
  parameter int W_IN = 8,
  parameter int SEL_DEMUX_WIDTH = 6,
  parameter int SEL_MUX_A_WIDTH = 4,
  parameter int SEL_MUX_B_WIDTH = 5
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



endmodule