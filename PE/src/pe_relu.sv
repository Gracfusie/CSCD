// -----------------------------------------------------------------------------
// ReLU for signed data (max(0, x)) -- Icarus-friendly
// -----------------------------------------------------------------------------
module pe_relu #(
  parameter int W = 24
) (
  input  logic signed [W-1:0] din,
  output logic signed [W-1:0] dout
);
  // Use signed compare instead of din[W-1] to avoid the Icarus limitation.
  assign dout = (din < 0) ? '0 : din;
endmodule
