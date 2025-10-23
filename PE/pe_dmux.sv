// -----------------------------------------------------------------------------
// 1-to-2 demultiplexer with gating (purely combinational)
// data goes to one of the outputs based on sel; the other output is zeroed.
// -----------------------------------------------------------------------------
module pe_dmux #(
  parameter int W = 24
) (
  input  logic [W-1:0] din,
  input  logic         sel,     // 0 -> y0, 1 -> y1
  output logic [W-1:0] y0,
  output logic [W-1:0] y1
);
  assign y0 = sel ? '0 : din;
  assign y1 = sel ? din : '0;
endmodule
