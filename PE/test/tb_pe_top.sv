`timescale 1ns/1ps
module tb_pe_top;
  import tb_pkg::*;

  // DUT memory-like interface
  logic clk, reset;
  logic        req_i;
  logic [3:0]  wen_i;
  logic [2:0]  addr_i;     // 0..4
  logic [31:0] wdata_i;
  logic [31:0] rdata_o;

  pe_top #(.ADDR_W(3)) dut (
    .clk, .reset,
    .req_i, .wen_i, .addr_i, .wdata_i, .rdata_o
  );

  // clock
  initial clk=0; always #5 clk=~clk;

  // simple bus model (registered reads in 1 cycle)
  task automatic bus_write(input int unsigned addr, input logic [31:0] data);
    @(negedge clk);
    req_i  = 1'b1;
    wen_i  = 4'hF;
    addr_i = addr[2:0];
    wdata_i= data;
    @(negedge clk);
    wen_i  = 4'h0;
  endtask

  task automatic bus_read(input int unsigned addr, output logic [31:0] data);
    @(negedge clk);
    req_i  = 1'b1;
    wen_i  = 4'h0;
    addr_i = addr[2:0];
    @(negedge clk);     // one-cycle registered read
    data = rdata_o;
  endtask

  // CTRL bitfields (match pe_top map)
  localparam int ADDR_A      = 0;
  localparam int ADDR_B      = 1;
  localparam int ADDR_CTRL   = 2;
  localparam int ADDR_RES    = 3;
  localparam int ADDR_STATUS = 4;

  function automatic logic [31:0] mk_ctrl(bit start, bit mode, bit clear);
    return {29'b0, clear, mode, start};
  endfunction

  // golden state
  int signed acc_ref;

  // one operation through memory interface
  task automatic do_memop(
      input byte unsigned a,
      input byte signed   b,
      input bit           mode,
      input bit           clear_acc
  );
    logic [31:0] rd;
    // Optional clear
    if (clear_acc) begin
      bus_write(ADDR_CTRL, mk_ctrl(1'b0, mode, 1'b1)); // pulse clear
    end

    // program operands
    bus_write(ADDR_A, {24'h0, a});
    bus_write(ADDR_B, {{24{b[7]}}, b});               // sign extended write

    // start with mode bit
    bus_write(ADDR_CTRL, mk_ctrl(1'b1, mode, 1'b0));

    // poll STATUS (sticky valid). Reads are word-based (offsets +4 bytes).
    // Per lab, req_i must be driven to allow reads. :contentReference[oaicite:5]{index=5}
    repeat (2) @(negedge clk); // one op latency is tiny, 1-2 cycles is enough
    int unsigned tries = 0;
    do begin
      bus_read(ADDR_STATUS, rd);
      tries++;
      if (tries > 50) $fatal("Timeout waiting for STATUS");
    end while (rd[0] == 1'b0);

    // read result
    bus_read(ADDR_RES, rd);

    // Scoreboard
    if (clear_acc) acc_ref = 0;
    acc_ref = golden_mac_step(acc_ref, a, b);
    int signed exp = golden_out(acc_ref, mode);

    if ($signed(rd) !== exp)
      $fatal("E2E mismatch: a=%0d b=%0d mode=%0d clear=%0d  got=%0d exp=%0d",
             a, b, mode, clear_acc, $signed(rd), exp);
  endtask

  initial begin
`ifdef DUMPFSDB
    $fsdbDumpfile("tb_pe_top.fsdb"); $fsdbDumpvars(0,tb_pe_top);
`endif

    // reset
    req_i=1'b1; wen_i=4'h0; addr_i='0; wdata_i='0; acc_ref=0;
    reset=1; repeat(3) @(negedge clk); reset=0;

    // ---------------------------
    // 1) Simple directed cases
    // ---------------------------
    do_memop(8'd5,   8'sd3,   1'b0, 1'b1);   // clear, result 15
    do_memop(8'd10,  8'sd-2,  1'b0, 1'b0);   // accumulate -> -5
    do_memop(8'd0,   8'sd0,   1'b1, 1'b0);   // show ReLU(-5)=0

    // ---------------------------
    // 2) Corner values
    // ---------------------------
    do_memop(8'd255, 8'sd127, 1'b0, 1'b0);
    do_memop(8'd255, 8'sd-128,1'b1, 1'b0);

    // ---------------------------
    // 3) Mini "CNN inner-product" workload
    // ---------------------------
    byte unsigned aa [0:15];
    byte signed   bb [0:15];
    foreach (aa[i]) begin
      aa[i] = i;                                      // 0..15
      bb[i] = (i%2==0) ? $signed(i-8) : $signed(8-i); // mix +/- weights
    end
    // Start new output channel
    do_memop(8'd0, 8'sd0, 1'b0, 1'b1); // clear only (NOP op)
    foreach (aa[i]) do_memop(aa[i], bb[i], 1'b0, 1'b0);
    // Read ReLU view of the final sum
    do_memop(8'd0, 8'sd0, 1'b1, 1'b0);

    // ---------------------------
    // 4) Randomized regression
    // ---------------------------
    for (int t=0; t<200; t++) begin
      byte unsigned a = $urandom_range(0,255);
      byte signed   b = $urandom_range(-128,127);
      bit mode = $urandom_range(0,1);
      bit clr  = (t%50==0); // occasionally clear like layer boundary
      do_memop(a,b,mode,clr);
    end

    $display("[pe_top] PASS — all directed & randomized workloads matched.");
    $finish;
  end
endmodule
