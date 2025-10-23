`timescale 1ns/1ps
module tb_pe_relu;

  logic signed [23:0] din, dout;
  pe_relu #(.W(24)) dut (.din(din), .dout(dout));

  initial begin
    din = 24'sd0;   #1 if (dout!==0)           $fatal(1, "ReLU 0 failed");
    din = 24'sd7;   #1 if (dout!==24'sd7)      $fatal(1, "ReLU + failed");
    din = -24'sd1;  #1 if (dout!==0)           $fatal(1, "ReLU -1 failed");
    din = -24'sd123456; #1 if (dout!==0)       $fatal(1, "ReLU neg large failed");

`ifdef DUMPFSDB
    $fsdbDumpfile("tb_pe_relu.fsdb"); $fsdbDumpvars(0,tb_pe_relu);
`endif
    $display("[pe_relu] PASS");
    $finish;
  end
endmodule
