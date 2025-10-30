`timescale 1ns/1ps

// Top-level testbench for the memory-like PE wrapper
module tb_pe_top;
  import tb_pkg::*;  // golden model helpers

  // ---------------------------------------------------------------------------
  // DUT memory-like interface
  // ---------------------------------------------------------------------------
  logic               clk, reset;
  logic               req_i;
  logic [3:0]         wen_i;
  logic [2:0]         addr_i;     // word index (0..4)
  logic [31:0]        wdata_i;
  logic [31:0]        rdata_o;

  // Address map (must match pe_top.sv)
  localparam int ADDR_A      = 0;
  localparam int ADDR_B      = 1;
  localparam int ADDR_CTRL   = 2;
  localparam int ADDR_RES    = 3;
  localparam int ADDR_STATUS = 4;

  // Instantiate DUT
  pe_top #(.ADDR_W(3)) dut (
    .clk, .reset,
    .req_i, .wen_i, .addr_i, .wdata_i, .rdata_o
  );

  // ---------------------------------------------------------------------------
  // Clock / reset
  // ---------------------------------------------------------------------------
  initial clk = 0;
  always #5 clk = ~clk;   // 100 MHz

  // Optional wave dumps
`ifdef DUMPFSDB
  initial begin
    $fsdbDumpfile("tb_pe_top.fsdb");
    $fsdbDumpvars(0, tb_pe_top);
  end
`elsif DUMPVCD
  initial begin
    $dumpfile("tb_pe_top.vcd");
    $dumpvars(0, tb_pe_top);
  end
`endif

  // ---------------------------------------------------------------------------
  // Simple "bus" model
  // - Writes: assert wen_i!=0 for one cycle at negedge
  // - Reads : registered one-cycle read (pe_top returns data next cycle)
  // ---------------------------------------------------------------------------
  task automatic bus_write(input int unsigned addr, input logic [31:0] data);
    @(negedge clk);
    req_i   = 1'b1;
    wen_i   = 4'hF;
    addr_i  = addr[2:0];
    wdata_i = data;
    @(negedge clk);
    wen_i   = 4'h0;    // deassert write enables
  endtask

  task automatic bus_read(input int unsigned addr, output logic [31:0] data);
    @(negedge clk);
    req_i   = 1'b1;
    wen_i   = 4'h0;
    addr_i  = addr[2:0];
    @(negedge clk);          // one registered latency
    data = rdata_o;
  endtask

  // CTRL word helper: {29'b0, clear, mode, start}
  function automatic logic [31:0] mk_ctrl(bit start, bit mode, bit clear);
    mk_ctrl = {29'b0, clear, mode, start};
  endfunction

  // ---------------------------------------------------------------------------
  // Golden/scoreboard state
  // ---------------------------------------------------------------------------
  int signed acc_ref;   // 24-bit signed accumulator value as int (sign-extended)

  // Utility: generate random bytes in a way that is robust on various iverilog versions
  function automatic byte unsigned rand_u8();
    rand_u8 = byte'($urandom & 8'hFF);
  endfunction

  function automatic byte signed rand_s8();
    int v = $urandom & 8'hFF;       // 0..255
    rand_s8 = byte signed'( (v>127) ? (v-256) : v );
  endfunction

  // One full memory-transaction "operation":
  //  - optional clear
  //  - program A/B
  //  - start with mode
  //  - poll STATUS then read RES
  //  - check against golden model (wrap24 + optional ReLU view)
  task automatic do_memop(
      input byte unsigned a,
      input byte signed   b,
      input bit           mode,
      input bit           clear_acc
  );
    logic [31:0] rd;

    // Optional clear pulse (also programs mode bit for visibility)
    if (clear_acc) begin
      bus_write(ADDR_CTRL, mk_ctrl(1'b0, mode, 1'b1));
    end

    // Program operands
    bus_write(ADDR_A, {24'h0, a});
    bus_write(ADDR_B, {{24{b[7]}}, b});   // sign-extend to 32

    // Start with chosen mode
    bus_write(ADDR_CTRL, mk_ctrl(1'b1, mode, 1'b0));

    // Small wait then poll STATUS[0] (sticky)
    repeat (2) @(negedge clk);
    int unsigned tries = 0;
    do begin
      bus_read(ADDR_STATUS, rd);
      tries++;
      if (tries > 50) $fatal(1, "Timeout waiting for STATUS valid");
    end while (rd[0] == 1'b0);

    // Read result
    bus_read(ADDR_RES, rd);

    // Golden model update/compare
    if (clear_acc) acc_ref = 0;
    acc_ref = golden_mac_step(acc_ref, a, b);
    int signed exp = golden_out(acc_ref, mode);

    if ($signed(rd) !== exp) begin
      $fatal(1, $sformatf("E2E mismatch: a=%0d b=%0d mode=%0d clear=%0d  got=%0d exp=%0d",
                          a, b, mode, clear_acc, $signed(rd), exp));
    end
  endtask

  // ---------------------------------------------------------------------------
  // Test sequence
  // ---------------------------------------------------------------------------
  initial begin
    // Reset & defaults
    req_i   = 1'b1;     // drive like SRAM (kept high)
    wen_i   = 4'h0;
    addr_i  = '0;
    wdata_i = '0;
    acc_ref = 0;

    reset = 1;
    repeat (3) @(negedge clk);
    reset = 0;

    // ---------------------------
    // 1) Simple directed cases
    // ---------------------------
    // Clear + positive product → raw
    do_memop(8'd5,    8'sd3,     1'b0, 1'b1);  // 15
    // Accumulate a negative product → raw negative
    do_memop(8'd10,   8'sd-2,    1'b0, 1'b0);  // 15 + (-20) = -5
    // Observe ReLU view (should be 0)
    do_memop(8'd0,    8'sd0,     1'b1, 1'b0);  // ReLU(-5) = 0

    // ---------------------------
    // 2) Corner/edge values
    // ---------------------------
    do_memop(8'd255,  8'sd127,   1'b0, 1'b0);  // large positive add
    do_memop(8'd255,  8'sd-128,  1'b1, 1'b0);  // large negative add, show ReLU

    // ---------------------------
    // 3) Overflow / wrap behavior stress
    //    Use repeated large positives to force 24b wrap-around
    // ---------------------------
    do_memop(8'd0, 8'sd0, 1'b0, 1'b1);         // explicit clear (NOP op)
    for (int k=0; k<200; k++) begin
      do_memop(8'd255, 8'sd127, 1'b0, 1'b0);
    end
    // Observe ReLU view of wrapped sum
    do_memop(8'd0, 8'sd0, 1'b1, 1'b0);

    // ---------------------------
    // 4) Mini "CNN inner-product" workload
    //    Deterministic vectors with mix of signs
    // ---------------------------
    // Start a fresh accumulation
    do_memop(8'd0, 8'sd0, 1'b0, 1'b1);
    for (int i=0; i<16; i++) begin
      byte unsigned aa = byte'(i);                    // 0..15
      byte signed   bb = (i%2==0) ? byte'(i-8) : byte'(8-i);
      do_memop(aa, bb, 1'b0, 1'b0);
    end
    // ReLU view after the dot-product
    do_memop(8'd0, 8'sd0, 1'b1, 1'b0);

    // ---------------------------
    // 5) Randomized regression
    //    Occasional clear to mimic layer/tile boundaries
    // ---------------------------
    for (int t=0; t<200; t++) begin
      byte unsigned a = rand_u8();
      byte signed   b = rand_s8();
      bit mode = (t[0]);        // alternate modes 0/1
      bit clr  = (t%50==0);     // periodic clear
      do_memop(a, b, mode, clr);
    end

    $display("[tb_pe_top] PASS — all directed, stress, and randomized workloads matched.");
    $finish;
  end

endmodule
