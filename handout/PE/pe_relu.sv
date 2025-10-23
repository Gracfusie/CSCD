// ReLU for signed data; negatives clamp to zero.
module pe_relu #(
  parameter int WIDTH = 24
) (
  input  logic signed [WIDTH-1:0] din,
  output logic signed [WIDTH-1:0] dout
);
  always_comb begin
    if (din[WIDTH-1]) dout = '0;  // negative → 0
    else               dout = din; // pass-through
  end
endmodule
