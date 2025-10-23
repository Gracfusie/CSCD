// -----------------------------------------------------------------------------
// Memory-like top wrapper for the PE core.
// - 32-bit word port matches the simple SRAM-like slave used in the lab setup.
// - No wait states; reads return registered data in 1 cycle.
// Map this block to a base address (e.g., 0x7000_0000) via the AXI crossbar,
// and bridge with axi2mem like SRAM (see lab example).  :contentReference[oaicite:3]{index=3}
// -----------------------------------------------------------------------------
module pe_top #(
  parameter int ADDR_W = 3  // enough for 0..4
) (
  input  logic               clk,
  input  logic               reset,        // high-active

  // SRAM-like memory port (compatible with axi2mem style)
  input  logic               req_i,        // access qualifier (assume always 1'b1 OK)
  input  logic [3:0]         wen_i,        // byte enables; write if any bit=1
  input  logic [ADDR_W-1:0]  addr_i,       // word index (offset / 4)
  input  logic [31:0]        wdata_i,
  output logic [31:0]        rdata_o
);

  // Address map
  localparam int ADDR_A       = 0;
  localparam int ADDR_B       = 1;
  localparam int ADDR_CTRL    = 2;
  localparam int ADDR_RES     = 3;
  localparam int ADDR_STATUS  = 4;

  // ------------------------------------------------------------
  // Shadow registers / control
  // ------------------------------------------------------------
  logic        start_pulse;
  logic        clear_acc_pulse;
  logic        mode_sel_q;

  logic [7:0]  a_q;
  logic signed [7:0] b_q;

  // Write detect
  wire do_write = req_i & (|wen_i);

  // Decode & writes (byte enables are honored only for [7:0])
  always_ff @(posedge clk or posedge reset) begin
    if (reset) begin
      a_q             <= '0;
      b_q             <= '0;
      mode_sel_q      <= 1'b0;
      start_pulse     <= 1'b0;
      clear_acc_pulse <= 1'b0;
    end else begin
      start_pulse     <= 1'b0; // default: one-shot
      clear_acc_pulse <= 1'b0;

      if (do_write) begin
        unique case (addr_i)
          ADDR_A: begin
            if (wen_i[0]) a_q <= wdata_i[7:0];
          end
          ADDR_B: begin
            if (wen_i[0]) b_q <= wdata_i[7:0];
          end
          ADDR_CTRL: begin
            // bit0: start, bit1: mode_sel, bit2: clear_acc
            if (wen_i != 4'b0000) begin
              if (wdata_i[1] !== 1'bx) mode_sel_q      <= wdata_i[1];
              if (wdata_i[0])          start_pulse     <= 1'b1;
              if (wdata_i[2])          clear_acc_pulse <= 1'b1;
            end
          end
          default: /* no-op */;
        endcase
      end
    end
  end

  // Local reset to clear the accumulator without disturbing the rest of the system
  wire core_reset = reset | clear_acc_pulse;

  // ------------------------------------------------------------
  // Core
  // ------------------------------------------------------------
  logic        out_vld;
  logic signed [23:0] pro_sum;

  pe_core u_core (
    .clk      (clk),
    .reset    (core_reset),
    .read_in  (start_pulse),
    .mode_sel (mode_sel_q),
    .a_mul    (a_q),
    .b_mul    (b_q),
    .out_vld  (out_vld),
    .pro_sum  (pro_sum)
  );

  // Latch last result when valid; expose status
  logic signed [23:0] result_q;
  logic               vld_sticky_q;

  always_ff @(posedge clk or posedge reset) begin
    if (reset) begin
      result_q      <= '0;
      vld_sticky_q  <= 1'b0;
    end else begin
      // Clear status at new start
      if (start_pulse) vld_sticky_q <= 1'b0;

      if (out_vld) begin
        result_q     <= pro_sum;
        vld_sticky_q <= 1'b1;
      end
    end
  end

  // Reads: 1-cycle registered readout
  logic [31:0] rdata_d, rdata_q;

  always_comb begin
    unique case (addr_i)
      ADDR_A:      rdata_d = {24'h0, a_q};
      ADDR_B:      rdata_d = {{24{b_q[7]}}, b_q};  // sign-extend 8->32
      ADDR_CTRL:   rdata_d = {29'b0, 1'b0/*clear*/, mode_sel_q, 1'b0/*start*/};
      ADDR_RES:    rdata_d = {{8{result_q[23]}}, result_q}; // sign-extend 24->32
      ADDR_STATUS: rdata_d = {31'b0, vld_sticky_q};
      default:     rdata_d = 32'h0;
    endcase
  end

  always_ff @(posedge clk or posedge reset) begin
    if (reset) rdata_q <= '0;
    else       rdata_q <= rdata_d;
  end

  assign rdata_o = rdata_q;

endmodule
