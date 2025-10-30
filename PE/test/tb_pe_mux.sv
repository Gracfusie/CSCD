`timescale 1ns/1ps
`default_nettype none

//------------------------------------------------------------------------------
// Icarus-friendly testbench for new array-input mux (N->1)
// - Top name: tb_pe_mux  (matches your Makefile)
// - Params override via: -P tb_pe_mux.WIDTH=.. -P tb_pe_mux.SEL_WIDTH=..
// - Optional plusargs:   +NUM_RAND=NN  +WAVES
//------------------------------------------------------------------------------
module tb_pe_mux;

  // Parameters
  parameter integer WIDTH     = 8;
  parameter integer SEL_WIDTH = 3;                 // N = 2^SEL_WIDTH
  localparam integer N_IN     = (1 << SEL_WIDTH);

  // DUT signals (use plain reg/wire for maximum Icarus compatibility)
  reg  [WIDTH-1:0]     data_in [0:N_IN-1];
  reg  [SEL_WIDTH-1:0] sel;
  wire [WIDTH-1:0]     data_out;

  // expation register (declared at module scope so tasks can use it)
  reg  [WIDTH-1:0]     exp;

  // -------------------------
  // DUT: new module "mux"
  // -------------------------
  pe_mux #(
    .WIDTH(WIDTH),
    .SEL_WIDTH(SEL_WIDTH)
  ) dut (
    .data_in (data_in),
    .sel     (sel),
    .data_out(data_out)
  );

  // -------------------------
  // Pattern loaders
  // -------------------------
  task load_incrementing;
    integer i;
    begin
      for (i = 0; i < N_IN; i = i + 1)
        data_in[i] = i;           // truncates to WIDTH as needed
    end
  endtask

  task load_one_hot;
    integer i, bit_index;
    begin
      for (i = 0; i < N_IN; i = i + 1) begin
        bit_index  = i % WIDTH;
        data_in[i] = (1 << bit_index);
      end
    end
  endtask

  task load_all_same;
    input [WIDTH-1:0] v;
    integer i;
    begin
      for (i = 0; i < N_IN; i = i + 1)
        data_in[i] = v;
    end
  endtask

  task load_random;
    integer i;
    begin
      for (i = 0; i < N_IN; i = i + 1)
        data_in[i] = $urandom;
    end
  endtask

  // -------------------------
  // Checker
  // -------------------------
  task check_select;
    input integer s;
    input integer tag_id;
    begin
      sel    = s;               // auto-truncates to SEL_WIDTH
      exp = data_in[s];      // integer index into unpacked array
      #1;                       // settle (combinational)
      if (data_out !== exp) begin
        $display("[%0t] FAIL tag=%0d sel=%0d exp=0x%0h got=0x%0h",
                 $time, tag_id, s, exp, data_out);
        $finish(2);
      end else begin
        $display("[%0t] PASS tag=%0d sel=%0d out=0x%0h",
                 $time, tag_id, s, data_out);
      end
    end
  endtask

  // -------------------------
  // Main test
  // -------------------------
  reg [SEL_WIDTH-1:0] fixed_sel;

  initial begin
    integer NUM_RAND;
    integer s, t, k, tag;

    // default + plusarg
    NUM_RAND = 50;
    if ($value$plusargs("NUM_RAND=%d", NUM_RAND)) begin end

    // init
    sel = {SEL_WIDTH{1'b0}};
    for (s = 0; s < N_IN; s = s + 1) data_in[s] = {WIDTH{1'b0}};

    // 1) Directed patterns
    load_incrementing();             tag = 100;
    for (s = 0; s < N_IN; s = s + 1) check_select(s, tag);

    load_one_hot();                  tag = 200;
    for (s = 0; s < N_IN; s = s + 1) check_select(s, tag);

    load_all_same({WIDTH{1'b0}});    tag = 300;
    for (s = 0; s < N_IN; s = s + 1) check_select(s, tag);

    load_all_same({WIDTH{1'b1}});    tag = 400;
    for (s = 0; s < N_IN; s = s + 1) check_select(s, tag);

    // 2) Randomized patterns
    for (t = 0; t < NUM_RAND; t = t + 1) begin
      load_random();                 tag = 500 + t;
      for (s = 0; s < N_IN; s = s + 1) check_select(s, tag);
    end

    // 3) Sweep select on one fixed vector
    load_random();                   tag = 600;
    for (s = 0; s < N_IN; s = s + 1) check_select(s, tag);

    // 4) Sweep inputs while select fixed
    fixed_sel = N_IN/2;              tag = 700;
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
