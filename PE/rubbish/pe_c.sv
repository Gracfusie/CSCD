module pe_core (
  input  logic                  clk,          // work clock
  input  logic                  reset,        // reset signal, high active
  input  logic                  pe_en,      // start mult/acc 
  input  logic                  mode_sel,     // 0: raw; 1: ReLU
  input  logic                  reg_reset,   // reset accumulator 
  input  logic           [7:0]  a_mul,        // input1
  input  logic signed    [7:0]  b_mul,        // input2

  output logic                  results
);



endmodule