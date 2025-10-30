`timescale 1ns/1ps
module tb_pe_relu;
  // Testbench-configurable width
  parameter int W = 24;

  // Inputs: initialize at declaration for known start
  logic signed [W-1:0] din = '0;
  // Outputs: driven by DUT only
  logic signed [W-1:0] dout;

  pe_relu #(.W(W)) dut (.din(din), .dout(dout));

  // Helper: cast an integer to signed [W-1:0]
  function automatic logic signed [W-1:0] S(input integer val);
    S = val; // truncates/extends as needed
  endfunction

  // Waveforms: enable with +vcd, or compile with -DDUMPFSDB (Verdi)
  initial begin
`ifdef DUMPFSDB
    $fsdbDumpfile("tb_pe_relu.fsdb");
    $fsdbDumpvars(0, tb_pe_relu);
`endif
    if ($test$plusargs("vcd")) begin
      $dumpfile("tb_pe_relu.vcd");
      $dumpvars(0, tb_pe_relu);
    end
  end

  initial begin
    // Let time-0 init propagate
    #0;
    #1;

    // ReLU tests
    din = '0;
    #1;
    if (dout !== '0) $fatal(1, "ReLU 0 failed (dout=%0d)", dout);

    din = S(7);
    #1;
    if (dout !== S(7)) $fatal(1, "ReLU + failed (dout=%0d)", dout);

    din = S(-1);
    #1;
    if (dout !== '0) $fatal(1, "ReLU -1 failed (dout=%0d)", dout);

    din = S(-123456);
    #1;
    if (dout !== '0) $fatal(1, "ReLU neg large failed (dout=%0d)", dout);

    $display("[pe_relu] PASS");
    $finish;
  end
endmodule
