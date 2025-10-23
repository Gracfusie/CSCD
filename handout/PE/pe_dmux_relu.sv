// -----------------------------------------------------------------------------
// PE core
//  - 8-bit unsigned A × 8-bit signed B → 16-bit product
//  - 24-bit signed accumulator with clear/start behavior
//  - DMUX #1 can convert the running sum to a 1-bit decision (>= threshold)
//  - DMUX #2 can bypass or apply ReLU to the 24-bit stream
//  - out_vld pulses when a MAC happens (read_in=1)
// -----------------------------------------------------------------------------
module pe_core (
  input  logic                  clk,
  input  logic                  reset,        // active high
  // MAC control
  input  logic                  read_in,      // one-cycle pulse to do a MAC
  input  logic                  mode_sel,     // 0: start (load product), 1: accumulate
  input  logic                  clr_acc,      // async to read_in; clears accumulator
  // Post-processing control
  input  logic                  bit_sel,      // to DMUX #1: 1 → emit 1-bit decision
  input  logic                  relu_en,      // to DMUX #2: 1 → apply ReLU
  input  logic signed [23:0]    thresh,       // decision threshold for DMUX #1
  // Operands
  input  logic          [7:0]   a_mul,        // UNSIGNED
  input  logic signed   [7:0]   b_mul,        // SIGNED
  // Status/outputs
  output logic                  out_vld,      // pulses when accumulator updates
  output logic signed [23:0]    acc_raw,      // raw accumulator (for debug/chaining)
  output logic                  recog_bit,    // 1-bit decision from DMUX #1
  output logic signed [23:0]    data24_out    // 24-bit path after DMUX #2
);

  // Multiply (combinational)
  logic signed [15:0] prod_s16;
  always_comb begin
    prod_s16 = $signed({1'b0, a_mul}) * $signed(b_mul); // keep A unsigned
  end

  // Sum with sign-extension to 24 bits
  logic signed [23:0] sum_24, acc_q, acc_d;
  assign sum_24 = acc_q + $signed({{8{prod_s16[15]}}, prod_s16});

  // Accumulator update
  always_comb begin
    acc_d   = acc_q;
    if (clr_acc) begin
      acc_d = '0;
    end else if (read_in) begin
      acc_d = (mode_sel == 1'b0)
              ? $signed({{8{prod_s16[15]}}, prod_s16}) // start (load product)
              : sum_24;                                // accumulate
    end
  end

  always_ff @(posedge clk or posedge reset) begin
    if (reset) begin
      acc_q   <= '0;
      out_vld <= 1'b0;
    end else begin
      acc_q   <= acc_d;
      // valid goes high when we actually perform a MAC
      out_vld <= read_in & ~clr_acc;
    end
  end

  // DMUX #1: 24-bit stream → either 1-bit decision or pass 24-bit forward.
  // Feed the *new* sum when a MAC happens; otherwise hold the last acc value.
  logic signed [23:0] stream_24;
  assign stream_24 = (read_in && !clr_acc)
                     ? ((mode_sel == 1'b0)
                         ? $signed({{8{prod_s16[15]}}, prod_s16})
                         : sum_24)
                     : acc_q;

  logic signed [23:0] dmux1_pass;

  pe_dmux_bit #(.WIDTH(24)) u_dmux1 (
    .sel_bit (bit_sel),
    .in_val  (stream_24),
    .thresh  (thresh),
    .bit_out (recog_bit),
    .data_out(dmux1_pass)
  );

  // DMUX #2: bypass vs ReLU
  pe_dmux_relu #(.WIDTH(24)) u_dmux2 (
    .sel_relu (relu_en),
    .in_val   (dmux1_pass),
    .out_val  (data24_out)
  );

  assign acc_raw = acc_q;

endmodule
