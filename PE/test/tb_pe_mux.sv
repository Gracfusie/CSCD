`timescale 1ns/1ps
`default_nettype none

//------------------------------------------------------------------------------
// Icarus-friendly testbench for array-input mux (N-to-1)
//------------------------------------------------------------------------------
module tb_pe_mux;

  // Parameters (override with: -P tb_pe_mux.WIDTH=16 -P tb_pe_mux.SEL_WIDTH=2)
  parameter integer WIDTH     = 8;
  parameter integer SEL_WIDTH = 3;                 // N = 2^SEL_WIDTH
  localparam integer N_IN     = (1 << SEL_WIDTH);

  // DUT signals
  logic [WIDTH-1:0]     data_in [N_IN-1:0];       // explicit unpacked range
  logic [SEL_WIDTH-1:0] sel;
  logic [WIDTH-1:0]     data_out;

  // DUT
  pe_mux #(
    .WIDTH(WIDTH),
    .SEL_WIDTH(SEL_WIDTH)
  ) dut (
    .data_in (data_in),
    .sel     (sel),
    .data_out(data_out)
  );

  // -----------------------
  // Pattern loaders (globals)
  // -----------------------
  task load_incrementing;
    integer i;
    begin
      for (i = 0; i < N_IN; i = i + 1) data_in[i] = i;
    end
  endtask

  task load_one_hot;
    integer i;
    integer bit_index;
    begin
      for (i = 0; i < N_IN; i = i + 1) begin
        bit_index = i % WIDTH;
        data_in[i] = (1 << bit_index); // width truncation is fine
      end
    end
  endtask

  task load_all_same(input logic [WIDTH-1:0] v);
    integer i;
    begin
      for (i = 0; i < N_IN; i = i + 1) data_in[i] = v;
    end
  endtask

  task load_random;
    integer i;
    begin
      for (i = 0; i < N_IN; i = i + 1) data_in[i] = $urandom;
    end
  endtask

  // -----------------------
  // Checker (uses globals)
  // -----------------------
  task check_select(input integer s, input integer tag_id);
    reg [WIDTH-1:0] expect;
    begin
      sel    = s[SEL_WIDTH-1:0];
      expect = data_in[s];
      #1; // settle
      if (data_out !== expect) begin
        $display("[%0t] FAIL tag=%0d sel=%0d exp=0x%0h got=0x%0h",
                 $time, tag_id, s, expect, data_out);
        $finish(2);
      end else begin
        $display("[%0t] PASS tag=%0d sel=%0d out=0x%0h",
                 $time, tag_id, s, data_out);
      end
    end
  endtask

  // -----------------------
  // Test sequence
  // -----------------------
  initial begin
    integer NUM_RAND;
    integer s, t, k;
    integer tag;

    // plusarg default
    NUM_RAND = 50;
    void'($value$plusargs("NUM_RAND=%d", NUM_RAND));

    // init
    sel = '0;
    for (s = 0; s < N_IN; s = s + 1) data_in[s] = '0;

    // 1) Directed
    load_incrementing();
    tag = 100;
    for (s = 0; s < N_IN; s = s + 1) check_select(s, tag);

    load_one_hot();
    tag = 200;
    for (s = 0; s < N_IN; s = s + 1) check_select(s, tag);

    load_all_same('0);
    tag = 300;
    for (s = 0; s < N_IN; s = s + 1) check_select(s, tag);

    load_all_same({WIDTH{1'b1}});
    tag = 400;
    for (s = 0; s < N_IN; s = s + 1) check_select(s, tag);

    // 2) Randomized patterns
    for (t = 0; t < NUM_RAND; t = t + 1) begin
      load_random();
      tag = 500 + t;
      for (s = 0; s < N_IN; s = s + 1) check_select(s, tag);
    end

    // 3) Sweep select on one fixed vector
    load_random();
    tag = 600;
    for (s = 0; s < N_IN; s = s + 1) check_select(s, tag);

    // 4) Sweep inputs while select fixed
    logic [SEL_WIDTH-1:0] fixed_sel;
    fixed_sel = (N_IN/2)[SEL_WIDTH-1:0];
    tag = 700;
    for (k = 0; k < 20; k = k + 1) begin
      load_random();
      check_select(fixed_sel, tag);
    end

    $display("All tests PASSED for WIDTH=%0d, SEL_WIDTH=%0d (N_IN=%0d).",
             WIDTH, SEL_WIDTH, N_IN);
    $finish;
  end

  // Optional VCD
  initial begin
    if ($test$plusargs("WAVES")) begin
      $dumpfile("wave_mux.vcd");
      $dumpvars(0, tb_pe_mux);
    end
  end

endmodule

`default_nettype wire
