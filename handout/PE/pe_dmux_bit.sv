// If sel_bit=1, compare to threshold and emit a 1-bit result; otherwise pass the 24-bit stream.
module pe_dmux_bit #(
  parameter int WIDTH = 24
) (
  input  logic                     sel_bit,   // 1: emit 1-bit decision; 0: pass 24-bit
  input  logic signed [WIDTH-1:0]  in_val,
  input  logic signed [WIDTH-1:0]  thresh,    // decision threshold
  output logic                     bit_out,   // valid when sel_bit=1
  output logic signed [WIDTH-1:0]  data_out   // valid when sel_bit=0
);
  always_comb begin
    bit_out  = 1'b0;
    data_out = '0;
    if (sel_bit) begin
      bit_out  = (in_val >= thresh);
    end else begin
      data_out = in_val;
    end
  end
endmodule
