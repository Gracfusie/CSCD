`timescale 1ns/1ps
module tb_pe_relu;
  import tb_pkg::*;

  logic signed [23:0] din, dout;
  pe_relu #(.W(24)) dut (.din(din), .dout(dout));

  initial begin
    din = 24'sd0;   #1 assert(dout==0) else $fatal("ReLU 0 failed");
    din = 24'sd7;   #1 assert(dout==7) else $fatal("ReLU + failed");
    din = -24'sd1;  #1 assert(dout==0) else $fatal("ReLU -1 failed");
    din = -24'sd123456; #1 assert(dout==0) else $fatal("ReLU neg large failed");

`ifdef DUMPFSDB
    $fsdbDumpfile("tb_pe_relu.fsdb"); $fsdbDumpvars(0,tb_pe_relu);
`endif
    $display("[pe_relu] PASS");
    $finish;
  end
endmodule
