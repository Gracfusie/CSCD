`timescale 1ns/1ps

module tb_pe_core;
  localparam int W_IN  = 8;
  localparam int W_MUL = 16;
  localparam int W_ACC = 24;

  // Clock/Reset
  logic clk;
  logic reset;

  // DUT I/O
  logic                   pe_en;
  logic                   mode_sel;    // 0: raw, 1: ReLU
  logic                   reg_reset;
  logic        [W_IN-1:0] a_mul;
  logic signed [W_IN-1:0] b_mul;
  logic signed [W_ACC-1:0] results;

  // DUT
  pe_core #(.W_IN(W_IN), .W_MUL(W_MUL), .W_ACC(W_ACC)) dut (
    .clk       (clk),
    .reset     (reset),
    .pe_en     (pe_en),
    .mode_sel  (mode_sel),
    .reg_reset (reg_reset),
    .a_mul     (a_mul),
    .b_mul     (b_mul),
    .results   (results)
  );

  // Golden model (cycle-accurate to DUT) for simple checks
  logic        [W_IN-1:0]  a_s0;
  logic signed [W_IN-1:0]  b_s0;
  logic signed [W_MUL-1:0] mul_s1;
  logic signed [W_ACC-1:0] acc_s2;
  logic signed [W_ACC-1:0] exp_results;

  // Control pipelines (shadow)
  logic pe_en_d1, pe_en_d2, pe_en_d3;
  logic mode_sel_d1, mode_sel_d2, mode_sel_d3;
  logic reg_reset_d1, reg_reset_d2, reg_reset_d3;

  function automatic signed [W_ACC-1:0] relu24(input signed [W_ACC-1:0] x);
    relu24 = (x < 0) ? '0 : x;
  endfunction

  // Clock
  initial clk = 0;
  always #5 clk = ~clk; // 100MHz

  // VCD
  initial begin
    $dumpfile("waveforms/pe_core.vcd");
    $dumpvars(0, tb_pe_core);
  end

  // Reset & stimulus sequence
  initial begin
    reset      = 1'b1;
    pe_en      = 1'b0;
    mode_sel   = 1'b0;
    reg_reset  = 1'b0;
    a_mul      = '0;
    b_mul      = '0;

    repeat (3) @(posedge clk);
    reset = 1'b0;

    // Clear accumulator once after reset (aligned to DUT’s pipeline internally)
    @(negedge clk);
    reg_reset = 1'b1; pe_en = 1'b0;
    @(negedge clk);
    reg_reset = 1'b0;

    // Feed a mix of values with bubbles and mode changes
    // C1
    apply_tx(1, 8'd3 ,  -8'sd2, 1'b0, 1'b0);  // acc +=  3 * -2 = -6
    // C2
    apply_tx(1, 8'd4 ,   8'sd1, 1'b0, 1'b0);  // acc +=  4 *  1 =  4  => -2
    // C3 (bubble)
    apply_tx(0, 8'd0 ,   8'sd0, 1'b0, 1'b0);
    // C4 (switch to ReLU)
    apply_tx(1, 8'd8 ,  -8'sd3, 1'b1, 1'b0);  // acc +=  8 * -3 = -24 => -26
    // C5
    apply_tx(1, 8'd2 ,   8'sd1, 1'b1, 1'b0);  // acc +=  2 *  1 =  2  => -24
    // C6
    apply_tx(1, 8'd10,  -8'sd5, 1'b1, 1'b0);  // acc += 10 * -5 = -50 => -74
    // C7 (clear accumulator; no new product)
    apply_tx(0, 8'd0 ,   8'sd0, 1'b1, 1'b1);  // clear takes effect at S2 two cycles later
    // C8
    apply_tx(1, 8'd1 ,  -8'sd1, 1'b1, 1'b0);  // acc += -1 (after clear)
    // C9 (back to raw)
    apply_tx(1, 8'd10,   8'sd1, 1'b0, 1'b0);  // acc grows positive
    // C10
    apply_tx(1, 8'd10,   8'sd1, 1'b0, 1'b0);
    // C11 (bubble)
    apply_tx(0, 8'd0 ,   8'sd0, 1'b0, 1'b0);
    // drain a few cycles
    repeat (6) apply_tx(0, 8'd0, 8'sd0, 1'b0, 1'b0);

    // Finish
    repeat (6) @(posedge clk);
    $finish;
  end

  // Drive helper: set signals on negative edge for clean setup to next posedge
  task automatic apply_tx(
    input logic         pe_en_i,
    input logic [7:0]   a_i,
    input logic signed [7:0] b_i,
    input logic         mode_i,
    input logic         reg_rst_i
  );
    @(negedge clk);
    pe_en     = pe_en_i;
    a_mul     = a_i;
    b_mul     = b_i;
    mode_sel  = mode_i;
    reg_reset = reg_rst_i;
  endtask

  // Golden model + comparisons (mimics DUT pipeline)
  always_ff @(posedge clk or posedge reset) begin
    if (reset) begin
      // controls
      pe_en_d1      <= 0; pe_en_d2 <= 0; pe_en_d3 <= 0;
      mode_sel_d1   <= 0; mode_sel_d2 <= 0; mode_sel_d3 <= 0;
      reg_reset_d1  <= 0; reg_reset_d2 <= 0; reg_reset_d3 <= 0;
      // data
      a_s0          <= '0;
      b_s0          <= '0;
      mul_s1        <= '0;
      acc_s2        <= '0;
      exp_results   <= '0;
    end else begin
      // control pipes
      pe_en_d1     <= pe_en;
      pe_en_d2     <= pe_en_d1;
      pe_en_d3     <= pe_en_d2;

      mode_sel_d1  <= mode_sel;
      mode_sel_d2  <= mode_sel_d1;
      mode_sel_d3  <= mode_sel_d2;

      reg_reset_d1 <= reg_reset;
      reg_reset_d2 <= reg_reset_d1;
      reg_reset_d3 <= reg_reset_d2;

      // S0
      if (pe_en) begin
        a_s0 <= a_mul;
        b_s0 <= b_mul;
      end
      // S1
      if (pe_en_d1) begin
        mul_s1 <= $signed({1'b0, a_s0}) * $signed(b_s0);
      end
      // S2
      if (reg_reset_d2) begin
        acc_s2 <= '0;
      end else if (pe_en_d2) begin
        acc_s2 <= acc_s2 + {{(W_ACC-W_MUL){mul_s1[W_MUL-1]}}, mul_s1};
      end
      // S3
      if (pe_en_d3) begin
        exp_results <= mode_sel_d3 ? relu24(acc_s2) : acc_s2;
      end

      // Check when DUT updates its output (only when pe_en_d3==1)
      if (pe_en_d3) begin
        if (results !== exp_results) begin
          $display("[%0t] MISMATCH: results=%0d, expected=%0d",
                   $time, $signed(results), $signed(exp_results));
        end else begin
          $display("[%0t] OK: results=%0d", $time, $signed(results));
        end
      end
    end
  end
endmodule
