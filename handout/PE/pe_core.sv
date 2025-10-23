// ------------------------------------------------------------
// PE compute core
// - 8-bit unsigned A times 8-bit signed B -> 16-bit signed
// - Accumulate into 24-bit signed register
// - mode_sel==0 : start-of-op MAC clears accumulator
// - mode_sel==1 : running accumulation across pulses
// - read_in     : one-cycle pulse to perform a single MAC
// - out_vld     : pulses high when pro_sum updates
// ------------------------------------------------------------
module pe_core (
  input  logic                  clk,          // work clock
  input  logic                  reset,        // reset signal, high active
  input  logic                  read_in,      // start mult/acc (1-cycle pulse)
  input  logic                  mode_sel,     // 0: clear acc on first mac; 1: keep accumulating
  input  logic           [7:0]  a_mul,        // operand a, UNSIGNED
  input  logic signed    [7:0]  b_mul,        // operand b, SIGNED
  input  logic                  clr_acc,      // explicit accumulator clear (1-cycle or level)
  output logic                  out_vld,      // out valid (1-cycle pulse when acc updates)
  output logic signed   [23:0]  pro_sum       // final accumulated result
);

  // product and accumulator
  logic signed [15:0]  prod_s16;
  logic signed [23:0]  acc_q, acc_d;

  // simple one-cycle product
  always_comb begin
    // cast a_mul to signed with a leading zero to preserve UNSIGNED meaning
    prod_s16 = $signed({1'b0, a_mul}) * $signed(b_mul);
  end

  // accumulator next-state
  always_comb begin
    acc_d   = acc_q;
    // default: no valid pulse
    out_vld = 1'b0;

    // clear has priority
    if (clr_acc) begin
      acc_d = '0;
    end
    // perform a single MAC when read_in is asserted
    else if (read_in) begin
      // mode_sel == 0 → treat this as start-of-op (clear then add product)
      // mode_sel == 1 → keep accumulating
      if (mode_sel == 1'b0) begin
        acc_d = $signed({{8{prod_s16[15]}}, prod_s16}); // load product
      end else begin
        acc_d = acc_q + $signed({{8{prod_s16[15]}}, prod_s16});
      end
      out_vld = 1'b1;
    end
  end

  // state registers
  always_ff @(posedge clk or posedge reset) begin
    if (reset) begin
      acc_q   <= '0;
      out_vld <= 1'b0;
    end else begin
      acc_q   <= acc_d;
      // out_vld is a pulse; keep one cycle only
      out_vld <= (read_in && !clr_acc);
    end
  end

  assign pro_sum = acc_q;

endmodule
