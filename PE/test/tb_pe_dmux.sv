`timescale 1ns/1ps
module tb_pe_dmux;
  logic [23:0] din, y0, y1;
  logic sel;

  pe_dmux #(.W(24)) dut (.din(din), .sel(sel), .y0(y0), .y1(y1));

  initial begin
    din = 24'h123456; sel = 0; #1;
    if (!(y0==din && y1==0)) $fatal(1, "DMUX sel=0 failed");
    sel = 1; #1;
    if (!(y0==0 && y1==din)) $fatal(1, "DMUX sel=1 failed");
`ifdef DUMPFSDB
    $fsdbDumpfile("tb_pe_dmux.fsdb"); $fsdbDumpvars(0,tb_pe_dmux);
`endif
    $display("[pe_dmux] PASS");
    $finish;
  end
endmodule
