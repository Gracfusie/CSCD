// -----------------------------------------------------------------------------
// Processing Element core: unsigned 8b * signed 8b -> signed 16b,
// accumulated into signed 24b with feedback register.
// Two-stage DMUX + ReLU path follows the provided diagram.
// mode_sel = 0 -> bypass (raw MAC sum)
// mode_sel = 1 -> ReLU(accumulated sum)
// Output valid is 1-cycle after read_in.
// -----------------------------------------------------------------------------
module pe_core (
  input  logic                  clk,          // work clock
  input  logic                  reset,        // reset signal, high active
  input  logic                  read_in,      // start mult/acc (one-cycle pulse)
  input  logic                  mode_sel,     // 0: raw; 1: ReLU
  input  logic           [7:0]  a_mul,        // operand a, UNSIGNED
  input  logic signed    [7:0]  b_mul,        // operand b, SIGNED

  output logic                  out_vld,      // out valid (1-cycle after read_in)
  output logic signed   [23:0]  pro_sum       // final accumulated result
);

  // --- Multiply (unsigned * signed) -> signed 16b
  logic signed [15:0] prod;
  assign prod = $signed({1'b0, a_mul}) * $signed(b_mul);

  // --- Accumulator (24b signed)
  logic signed [23:0] acc_q, acc_d;
  assign acc_d = acc_q + {{8{prod[15]}}, prod};  // sign-extend product to 24b

  always_ff @(posedge clk or posedge reset) begin
    if (reset) begin
      acc_q   <= '0;
      out_vld <= 1'b0;
    end else begin
      // capture when read_in asserted
      if (read_in) acc_q <= acc_d;
      // out_vld is the "operation taken" pulse delayed one cycle
      out_vld <= read_in;
    end
  end

  // --- Post-accumulate datapath (two demux stages + ReLU)
  // Stage 1 DMUX: either send to OUT0 directly (top path) or to stage 2
  logic signed [23:0] stg1_out0, stg1_to_stg2;
  pe_dmux #(.W(24)) u_dmux_stage1 (
    .din (acc_d),             // use acc_d so external sees the updated sum
    .sel (mode_sel),          // 0 -> OUT0, 1 -> go to stage 2
    .y0  (stg1_out0),
    .y1  (stg1_to_stg2)
  );

  // Stage 2: choose bypass vs ReLU
  logic signed [23:0] relu_out;
  pe_relu #(.W(24)) u_relu (.din(stg1_to_stg2), .dout(relu_out));

  logic signed [23:0] stg2_bypass, stg2_relu;
  pe_dmux #(.W(24)) u_dmux_stage2 (
    .din (stg1_to_stg2),
    .sel (1'b1),              // force selection to y1 -> ReLU leg in this design
    .y0  (stg2_bypass),       // unused (zero)
    .y1  (stg2_relu)          // goes into ReLU (wired above)
  );

  // Final select between stage1 OUT0 (raw) and stage2 ReLU
  always_comb begin
    unique case (mode_sel)
      1'b0: pro_sum = stg1_out0;  // raw accumulated sum
      1'b1: pro_sum = relu_out;   // ReLU(acc_d)
      default: pro_sum = stg1_out0;
    endcase
  end

endmodule
