// // -----------------------------------------------------------------------------
// // Pipelined PE core: 8x8 -> 16 mult, 24-bit accumulate, optional ReLU, MUX out
// //   Stages:
// //     S0: input registers (M1/M2) when pe_en=1
// //     S1: 8x8 -> 16-bit multiply (registered)
// //     S2: 24-bit accumulate with optional clear (registered)
// //     S3: ReLU + MUX selection (registered output)
// //   Total latency input->results: 3 cycles when pe_en is asserted
// // -----------------------------------------------------------------------------
// module pe_core #(
//   parameter int W_IN   = 8,
//   parameter int W_MUL  = 16,
//   parameter int W_ACC  = 24
// ) (
//   input  logic                    clk,          // work clock
//   input  logic                    reset,        // async, high-active
//   input  logic                    pe_en,        // start mult/acc 
//   input  logic                    mode_sel,     // 0: raw; 1: ReLU
//   input  logic                    reg_reset,    // clear accumulator (sync-piped)
//   input  logic         [W_IN-1:0] a_mul,        // input1 (treated as unsigned)
//   input  logic signed  [W_IN-1:0] b_mul,        // input2 (signed)

//   output logic signed [W_ACC-1:0] results       // final output
// );

//   // --------------------------
//   // Stage 0: input registers
//   // --------------------------
//   logic        [W_IN-1:0]  a_s0;
//   logic signed [W_IN-1:0]  b_s0;

//   // --------------------------
//   // Stage 1: multiplier reg
//   // --------------------------
//   logic signed [W_MUL-1:0] mul_s1;

//   // --------------------------
//   // Stage 2: accumulator reg
//   // --------------------------
//   logic signed [W_ACC-1:0] acc_s2;

//   // ReLU + MUX wires
//   logic signed [W_ACC-1:0] relu_out_s3;
//   logic signed [W_ACC-1:0] mux_out_s3;

//   // --------------------------
//   // Pipeline control (valid & controls alignment)
//   // --------------------------
//   logic pe_en_d1, pe_en_d2, pe_en_d3;
//   logic mode_sel_d1, mode_sel_d2, mode_sel_d3;
//   logic reg_reset_d1, reg_reset_d2, reg_reset_d3;

//   // --------------------------
//   // Submodules
//   // --------------------------
//   pe_relu #(.W(W_ACC)) u_relu (
//     .din  (acc_s2),
//     .dout (relu_out_s3)
//   );

//   pe_mux  #(.W(W_ACC)) u_mux (
//     .sel (mode_sel_d3),
//     .a   (acc_s2),       // raw
//     .b   (relu_out_s3),  // activated
//     .y   (mux_out_s3)
//   );

//   // --------------------------
//   // Async reset / sync pipeline
//   // --------------------------
//   always_ff @(posedge clk or posedge reset) begin
//     if (reset) begin
//       // controls
//       pe_en_d1     <= 1'b0;
//       pe_en_d2     <= 1'b0;
//       pe_en_d3     <= 1'b0;
//       mode_sel_d1  <= 1'b0;
//       mode_sel_d2  <= 1'b0;
//       mode_sel_d3  <= 1'b0;
//       reg_reset_d1 <= 1'b0;
//       reg_reset_d2 <= 1'b0;
//       reg_reset_d3 <= 1'b0;

//       // data pipeline
//       a_s0         <= '0;
//       b_s0         <= '0;
//       mul_s1       <= '0;
//       acc_s2       <= '0;
//       results      <= '0;

//     end else begin
//       // ---- control pipelining ----
//       pe_en_d1     <= pe_en;
//       pe_en_d2     <= pe_en_d1;
//       pe_en_d3     <= pe_en_d2;

//       mode_sel_d1  <= mode_sel;
//       mode_sel_d2  <= mode_sel_d1;
//       mode_sel_d3  <= mode_sel_d2;

//       reg_reset_d1 <= reg_reset;
//       reg_reset_d2 <= reg_reset_d1;
//       reg_reset_d3 <= reg_reset_d2;

//       // ---- S0: capture inputs when enabled ----
//       if (pe_en) begin
//         a_s0 <= a_mul;
//         b_s0 <= b_mul;
//       end

//       // ---- S1: multiply (registered) ----
//       if (pe_en_d1) begin
//         // Cast a_s0 to (positive) signed by zero-extending before $signed.
//         // b_s0 is already signed.
//         mul_s1 <= $signed({1'b0, a_s0}) * $signed(b_s0); // 9x8 -> 16 signed
//       end

//       // ---- S2: accumulate (registered) ----
//       // Allow clearing even if no new product (useful for starting a new MAC)
//       if (reg_reset_d2) begin
//         acc_s2 <= '0;
//       end else if (pe_en_d2) begin
//         // Sign-extend product to accumulator width then add
//         acc_s2 <= acc_s2 + {{(W_ACC-W_MUL){mul_s1[W_MUL-1]}}, mul_s1};
//       end

//       // ---- S3: output register (after ReLU/MUX) ----
//       if (pe_en_d3) begin
//         results <= mux_out_s3;
//       end
//     end
//   end

// endmodule

// -----------------------------------------------------------------------------
// Pipelined PE core: 8x8 -> 16 mult, 24-bit accumulate, optional ReLU, MUX out
//   Stages:
//     S0: input registers (M1/M2) when pe_en=1
//     S1: 8x8 -> 16-bit multiply (registered)
//     S2: 24-bit accumulate with optional clear (registered)
//     S3: ReLU + MUX selection (registered output)
//   Total latency input->results: 3 cycles when pe_en is asserted
//
// Note (2025-10-30):
// - Updated MUX instantiation to match new array-input module `mux`
//   (WIDTH=W_ACC, SEL_WIDTH=1). Dataflow and external interface unchanged.
// -----------------------------------------------------------------------------
module pe_core #(
  parameter int W_IN   = 8,
  parameter int W_MUL  = 16,
  parameter int W_ACC  = 24
) (
  input  logic                    clk,          // work clock
  input  logic                    reset,        // async, high-active
  input  logic                    pe_en,        // start mult/acc 
  input  logic                    mode_sel,     // 0: raw; 1: ReLU
  input  logic                    reg_reset,    // clear accumulator (sync-piped)
  input  logic         [W_IN-1:0] a_mul,        // input1 (treated as unsigned)
  input  logic signed  [W_IN-1:0] b_mul,        // input2 (signed)

  output logic signed [W_ACC-1:0] results       // final output
);

  // --------------------------
  // Stage 0: input registers
  // --------------------------
  logic        [W_IN-1:0]  a_s0;
  logic signed [W_IN-1:0]  b_s0;

  // --------------------------
  // Stage 1: multiplier reg
  // --------------------------
  logic signed [W_MUL-1:0] mul_s1;

  // --------------------------
  // Stage 2: accumulator reg
  // --------------------------
  logic signed [W_ACC-1:0] acc_s2;

  // ReLU + MUX wires
  logic signed [W_ACC-1:0] relu_out_s3;
  logic signed [W_ACC-1:0] mux_out_s3;

  // --------------------------
  // Pipeline control (valid & controls alignment)
  // --------------------------
  logic pe_en_d1, pe_en_d2, pe_en_d3;
  logic mode_sel_d1, mode_sel_d2, mode_sel_d3;
  logic reg_reset_d1, reg_reset_d2, reg_reset_d3;

  // --------------------------
  // Submodules
  // --------------------------
  pe_relu #(.W(W_ACC)) u_relu (
    .din  (acc_s2),
    .dout (relu_out_s3)
  );

  // New MUX wiring to match `mux` (array-input) interface:
  //   - Two inputs: [0]=raw acc, [1]=ReLU(acc)
  //   - Select is mode_sel_d3 (0: raw, 1: ReLU)
  logic [W_ACC-1:0] mux_inputs [1:0];
  logic [W_ACC-1:0] mux_data_out;

  assign mux_inputs[0] = acc_s2;       // raw
  assign mux_inputs[1] = relu_out_s3;  // activated

  pe_mux #(
    .WIDTH(W_ACC),
    .SEL_WIDTH(1)
  ) u_mux (
    .data_in (mux_inputs),
    .sel     (mode_sel_d3),
    .data_out(mux_data_out)
  );

  // Preserve signedness on local mux output view
  assign mux_out_s3 = mux_data_out;

  // --------------------------
  // Async reset / sync pipeline
  // --------------------------
  always_ff @(posedge clk or posedge reset) begin
    if (reset) begin
      // controls
      pe_en_d1     <= 1'b0;
      pe_en_d2     <= 1'b0;
      pe_en_d3     <= 1'b0;
      mode_sel_d1  <= 1'b0;
      mode_sel_d2  <= 1'b0;
      mode_sel_d3  <= 1'b0;
      reg_reset_d1 <= 1'b0;
      reg_reset_d2 <= 1'b0;
      reg_reset_d3 <= 1'b0;

      // data pipeline
      a_s0         <= '0;
      b_s0         <= '0;
      mul_s1       <= '0;
      acc_s2       <= '0;
      results      <= '0;

    end else begin
      // ---- control pipelining ----
      pe_en_d1     <= pe_en;
      pe_en_d2     <= pe_en_d1;
      pe_en_d3     <= pe_en_d2;

      mode_sel_d1  <= mode_sel;
      mode_sel_d2  <= mode_sel_d1;
      mode_sel_d3  <= mode_sel_d2;

      reg_reset_d1 <= reg_reset;
      reg_reset_d2 <= reg_reset_d1;
      reg_reset_d3 <= reg_reset_d2;

      // ---- S0: capture inputs when enabled ----
      if (pe_en) begin
        a_s0 <= a_mul;
        b_s0 <= b_mul;
      end

      // ---- S1: multiply (registered) ----
      if (pe_en_d1) begin
        // Cast a_s0 to (positive) signed by zero-extending before $signed.
        // b_s0 is already signed.
        mul_s1 <= $signed({1'b0, a_s0}) * $signed(b_s0); // 9x8 -> 16 signed (truncated)
      end

      // ---- S2: accumulate (registered) ----
      // Allow clearing even if no new product (useful for starting a new MAC)
      if (reg_reset_d2) begin
        acc_s2 <= '0;
      end else if (pe_en_d2) begin
        // Sign-extend product to accumulator width then add
        acc_s2 <= acc_s2 + {{(W_ACC-W_MUL){mul_s1[W_MUL-1]}}, mul_s1};
      end

      // ---- S3: output register (after ReLU/MUX) ----
      if (pe_en_d3) begin
        results <= mux_out_s3;
      end
    end
  end

endmodule

