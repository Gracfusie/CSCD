// -----------------------------------------------------------------------------
// Parametric 2:1 MUX (signed data)
// -----------------------------------------------------------------------------
module pe_mux #(
  parameter int W = 24
) (
  input  logic              sel,       // 0: a (raw), 1: b (activated)
  input  logic signed [W-1:0] a,
  input  logic signed [W-1:0] b,
  output logic signed [W-1:0] y
);
  always_comb begin
    y = sel ? b : a;
  end
endmodule
