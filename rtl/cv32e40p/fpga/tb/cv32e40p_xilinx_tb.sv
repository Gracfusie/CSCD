`timescale 1ns/1ns// testbench for the testharness module
module cv32e40p_xilinx_tb;

  // Signals for the testharness module
  logic fpga_clk_i;
  logic rst_ni;
  logic tck_i;
  logic tms_i;
  logic td_i;
  logic td_o;
  logic trst_ni;

  logic clk_led;
  logic tck_led;

  // NPU signal logger
  integer npu_log_fd;
  logic [31:0] prev_wdata;
  logic [31:0] prev_rdata;

  // Open log at time 0
  initial begin
    npu_log_fd = $fopen("/home/almalinux/workspace/CSCD/rtl/cv32e40p/fpga/output/npu_signals.log", "w");
    prev_wdata = 32'hx;
    prev_rdata = 32'hx;
  end

  // Instantiate the testharness module
  cv32e40p_xilinx i_cv32e40p_xilinx (
    // .fpga_clk_i(fpga_clk_i),
    // .rst_ni(rst_ni),
    // .tck_i,
    // .tms_i,
    // .td_i,
    // .td_o
    .clk_i(fpga_clk_i),
    .rst_ni(rst_ni),
    .tck_i(tck_i),
    .tms_i(tms_i),
    .td_i(td_i),
    .td_o(td_o),
    .clk_led(clk_led),
    .tck_led(tck_led)
  );

  // Clock generation (50% duty cycle)
  always #5 fpga_clk_i = ~fpga_clk_i;

  // Monitor NPU signals and log on any change
  always @(i_cv32e40p_xilinx.i_npu.wdata_i or i_cv32e40p_xilinx.i_npu.rdata_o) begin
    if (npu_log_fd != 0) begin
      if (i_cv32e40p_xilinx.i_npu.wdata_i !== prev_wdata ||
          i_cv32e40p_xilinx.i_npu.rdata_o !== prev_rdata) begin
        $fwrite(npu_log_fd, "%0t: wdata_i=%08h rdata_o=%08h\n", $time,
                i_cv32e40p_xilinx.i_npu.wdata_i,
                i_cv32e40p_xilinx.i_npu.rdata_o);
        $fflush(npu_log_fd);
        prev_wdata = i_cv32e40p_xilinx.i_npu.wdata_i;
        prev_rdata = i_cv32e40p_xilinx.i_npu.rdata_o;
      end
    end
  end

  // Testbench initial block
  initial begin
    // Initialize signals
    fpga_clk_i = 0;
    rst_ni = 0;
    tck_i = 0;
    tms_i = 0;
    td_i = 0;
    trst_ni = 0;

    // Apply reset for a few cycles
    #10 rst_ni = 1;
    trst_ni = 1;
    // Run simulation for 100 time units and finish
    #10000000;
    $writememh("/home/almalinux/workspace/CSCD/rtl/cv32e40p/fpga/output/sram_dump.hex", i_cv32e40p_xilinx.i_dcache_sram.mem);
    $display("SRAM dumped to sram_dump.hex");
    if (npu_log_fd != 0) begin
      $fclose(npu_log_fd);
      $display("NPU log closed (npu_signals.log)");
    end
    $finish;
  end

  // Dump waveforms for debugging (if needed)
  initial begin
    $fsdbDumpfile("waveform.fsdb");
    $fsdbDumpvars(0, cv32e40p_xilinx_tb);
    $fsdbDumpMDA();
  end

endmodule
