`timescale 1ns/1ps
module tb_pe_dmux;
  parameter int W = 24;

  // Initialize inputs at declaration
  logic [W-1:0] din = '0;
  logic         sel = 1'b0;

  // DUT outputs: never initialize/drive these in the TB
  logic [W-1:0] y0, y1;

  pe_dmux #(.W(W)) dut (.din(din), .sel(sel), .y0(y0), .y1(y1));

  // Optional waves
  initial begin
`ifdef DUMPFSDB
    $fsdbDumpfile("tb_pe_dmux.fsdb");
    $fsdbDumpvars(0, tb_pe_dmux);
`endif
    if ($test$plusargs("vcd")) begin
      $dumpfile("tb_pe_dmux.vcd");
      $dumpvars(0, tb_pe_dmux);
    end
  end

  initial begin
    // Allow time 0 init to propagate through DUT
    #0;   // delta
    #1;   // 1ns

    // At sel=0, din=0 → outputs should both be 0
    if (y0 !== '0 || y1 !== '0)
      $fatal(1, "Initial outputs not zero: y0=%h y1=%h", y0, y1);

    // Drive a value and check
    din = 'h123456; sel = 1'b0; #1;
    if (!(y0==din && y1=='0)) $fatal(1, "DMUX sel=0 failed: y0=%h y1=%h", y0, y1);

    sel = 1'b1; #1;
    if (!(y0=='0 && y1==din)) $fatal(1, "DMUX sel=1 failed: y0=%h y1=%h", y0, y1);

    $display("[pe_dmux] PASS");
    $finish;
  end
endmodule
