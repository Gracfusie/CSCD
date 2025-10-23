`timescale 1ns/1ps
module tb_pe_core;
  import tb_pkg::*;

  // DUT I/O
  logic clk, reset, read_in, mode_sel, out_vld;
  logic [7:0]      a_mul;
  logic signed [7:0] b_mul;
  logic signed [23:0] pro_sum;

  pe_core dut(
    .clk, .reset, .read_in, .mode_sel,
    .a_mul, .b_mul,
    .out_vld, .pro_sum
  );

  // clock
  initial clk=0; always #5 clk=~clk;

  // score
  int signed acc_ref;
  task automatic do_step(input byte unsigned a, input byte signed b, input bit mode);
    // hold inputs stable across read_in & the next cycle (since out_vld is delayed)
    a_mul   = a;
    b_mul   = b;
    mode_sel= mode;

    // compute reference
    acc_ref = golden_mac_step(acc_ref, a, b);
    int signed expect = golden_out(acc_ref, mode);

    // fire one-cycle read_in
    @(negedge clk); read_in = 1; @(negedge clk); read_in = 0;

    // sample when out_vld raises (next cycle)
    @(posedge clk);
    assert(out_vld===1) else $fatal("out_vld timing");
    // compare
    if ($signed(pro_sum) !== $signed(expect[23:0]))
      $fatal("Mismatch: a=%0d b=%0d mode=%0d  got=%0d exp=%0d",
             a, b, mode, $signed(pro_sum), expect);
  endtask

  initial begin
`ifdef DUMPFSDB
    $fsdbDumpfile("tb_pe_core.fsdb"); $fsdbDumpvars(0,tb_pe_core);
`endif
    // reset
    reset=1; read_in=0; mode_sel=0; a_mul=0; b_mul=0; acc_ref=0;
    repeat(3) @(negedge clk); reset=0;

    // Directed: single op
    do_step(8'd5, 8'sd3, 1'b0);      // 15
    // accumulate negative
    do_step(8'd10, 8'sd-2, 1'b0);    // 15 + (-20) = -5 (wrap24 ok)
    // ReLU view of negative sum
    do_step(8'd0, 8'sd0, 1'b1);      // acc unchanged -> ReLU(-5) = 0

    // Extremes
    do_step(8'd255, 8'sd127, 1'b0);
    do_step(8'd255, 8'sd-128, 1'b1);

    // Randomized regression
    foreach (int i[0:199]) begin
      byte unsigned a = $urandom_range(0,255);
      byte signed   b = $urandom_range(-128,127);
      bit mode = $urandom_range(0,1);
      do_step(a,b,mode);
    end

    $display("[pe_core] PASS");
    $finish;
  end
endmodule
