`timescale 1ns/1ps

module tb_pe_mux;
  localparam int W = 24;

  // DUT I/O
  logic                   sel;
  logic signed [W-1:0]    a, b;
  logic signed [W-1:0]    y;

  // DUT
  pe_mux #(.W(W)) dut (
    .sel(sel),
    .a  (a),
    .b  (b),
    .y  (y)
  );

  // VCD
  initial begin
    $dumpfile("waveforms/pe_mux.vcd");
    $dumpvars(0, tb_pe_mux);
  end

  // Stimulus
  initial begin
    sel = 0; a = 0; b = 0;
    #5;
    a = 24'sd100;  b = -24'sd50;
    #10 sel = 0;   // expect y=a
    #10 sel = 1;   // expect y=b
    #10 a = -24'sd12345; b = 24'sd7; sel = 0;
    #10 sel = 1;
    #10 a = 24'sd0; b = 24'sd0; sel = 0;
    #20 $finish;
  end

  // Simple monitor
  initial begin
    $display(" time   sel        a                b                y");
    $monitor("%5t   %0d  %0d  %0d  %0d", $time, sel, a, b, y);
  end
endmodule
