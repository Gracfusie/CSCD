// -----------------------------------------------------------------------------
// ReLU for signed data (max(0, x))
// -----------------------------------------------------------------------------
module pe_relu #(
  parameter int W = 24
) (
  input  logic signed [W-1:0] din,
  output logic signed [W-1:0] dout
);
  always_comb begin
    if (din[W-1]) dout = '0;  // negative -> zero
    else          dout = din; // pass-through
  end
endmodule
