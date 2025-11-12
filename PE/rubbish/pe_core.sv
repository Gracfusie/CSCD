module pe_core #(
  parameter int W_IN   = 8,
  parameter int W_MUL  = 16,
  parameter int W_ACC  = 24
) (
  input  logic                    clk,          // work clock
  input  logic                    rst_n,        // async, high-active
  input  logic                    pe_en,        // start mult/acc 
  input  logic                    mode_sel,     // 0: raw; 1: ReLU
  input  logic                    reg_reset,    // clear accumulator (sync-piped)
  input  logic         [W_IN-1:0] a_mul,        // input1 (treated as unsigned)
  input  logic signed  [W_IN-1:0] b_mul,        // input2 (signed)

  output logic signed [W_ACC-1:0] results       // final output
);

logic pe_en_reg, mode_sel_reg, reg_reset_reg;
logic        [W_IN-1:0]  a_reg;
logic signed [W_IN-1:0]  b_reg;
logic signed [W_MUL-1:0] mul_s0, mul_s1;
logic signed [W_ACC-1:0] acc_s0, acc_s1;
logic signed [W_ACC-1:0] relu_out_s0, relu_out_s1;
// assign mul = $signed({1'b0, a_reg}) * $signed(b_reg);
assign mul = $signed({1'b0, a_mul}) * $signed(b_mul);

always_ff @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    // mode_sel_reg <= 1'b0;
    // reg_reset_reg <= 1'b0;
    // a_reg <= '0;
    // b_reg <= '0;
    acc <= '0;
  end else begin
      // mode_sel_reg <= mode_sel;
      // reg_reset_reg <= reg_reset;
      // a_reg <= a_mul;
      // b_reg <= b_mul;
    if (reg_reset) begin
      acc <= '0;
    end else if (pe_en) begin
      acc <= acc + {{(W_ACC-W_MUL){mul[W_MUL-1]}}, mul};
    end
  end
end

pe_relu #(.W(W_ACC)) u_relu (
  .din  (acc),
  .dout (relu_out)
);

pe_mux #(
  .WIDTH(W_ACC),
  .DEPTH(2),
  .SEL_WIDTH(1)
) u_mux (
  .data_in ({acc, relu_out}),
  .sel     (mode_sel),
  .data_out(results)
);

endmodule

