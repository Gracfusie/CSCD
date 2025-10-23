// -----------------------------------------------------------------------------
// Memory-like PE wrapper (SRAM-style interface).
// Drop this behind your axi2mem bridge (same as SRAM) and give it a base addr.
// -----------------------------------------------------------------------------
module pe_memlike #(
  parameter int ADDR_WIDTH = 3   // 7 words used: 0..6
) (
  input  logic                   clk_i,
  input  logic                   rst_i,        // active high

  // SRAM-style bus
  input  logic                   req_i,
  input  logic [3:0]             wen_i,        // byte-enables; any nonzero => write
  input  logic [ADDR_WIDTH-1:0]  addr_i,       // word address
  input  logic [31:0]            data_i,
  output logic [31:0]            data_o
);

  // Registers mapped to words
  logic [7:0]             a_q;
  logic signed [7:0]      b_q;
  logic                   mode_sel_q, relu_en_q, bit_sel_q;
  logic signed [23:0]     thresh_q;

  // Pulses from CTRL writes
  logic start_pulse, clr_acc_pulse;

  // Core signals
  logic out_vld;
  logic signed [23:0] acc_raw, data24_out;
  logic recog_bit;

  // ------------------------ Core ------------------------
  pe_core u_core (
    .clk       (clk_i),
    .reset     (rst_i),
    .read_in   (start_pulse),
    .mode_sel  (mode_sel_q),
    .clr_acc   (clr_acc_pulse),
    .bit_sel   (bit_sel_q),
    .relu_en   (relu_en_q),
    .thresh    (thresh_q),
    .a_mul     (a_q),
    .b_mul     (b_q),
    .out_vld   (out_vld),
    .acc_raw   (acc_raw),
    .recog_bit (recog_bit),
    .data24_out(data24_out)
  );

  // ------------------------ Writes ----------------------
  wire do_write = req_i & (|wen_i);

  always_ff @(posedge clk_i or posedge rst_i) begin
    if (rst_i) begin
      a_q           <= '0;
      b_q           <= '0;
      mode_sel_q    <= 1'b0;
      relu_en_q     <= 1'b0;
      bit_sel_q     <= 1'b0;
      thresh_q      <= '0;
      start_pulse   <= 1'b0;
      clr_acc_pulse <= 1'b0;
    end else begin
      // default pulses deassert
      start_pulse   <= 1'b0;
      clr_acc_pulse <= 1'b0;

      if (do_write) begin
        unique case (addr_i)
          3'h0: if (wen_i[0]) a_q <= data_i[7:0];
          3'h1: if (wen_i[0]) b_q <= data_i[7:0];
          3'h2: if (wen_i[0]) begin
                  mode_sel_q    <= data_i[1];
                  relu_en_q     <= data_i[3];
                  bit_sel_q     <= data_i[4];
                  if (data_i[0]) start_pulse   <= 1'b1; // one MAC
                  if (data_i[2]) clr_acc_pulse <= 1'b1; // clear
                end
          3'h3: begin
                  // threshold[23:0] in low 24 bits
                  if (wen_i[0]) thresh_q[7:0]   <= data_i[7:0];
                  if (wen_i[1]) thresh_q[15:8]  <= data_i[15:8];
                  if (wen_i[2]) thresh_q[23:16] <= data_i[23:16];
                end
          default: /* no-op */;
        endcase
      end
    end
  end

  // ------------------------ Reads -----------------------
  always_comb begin
    logic [31:0] r = '0;
    unique case (addr_i)
      3'h0: r = {24'h0, a_q};
      3'h1: r = {24'h0, b_q[7:0]};
      3'h2: r = {23'h0, out_vld, 3'b000, bit_sel_q, relu_en_q, mode_sel_q, 1'b0}; // status+ctrl view
      3'h3: r = {8'h0, thresh_q};
      3'h4: r = {{8{data24_out[23]}}, data24_out};
      3'h5: r = {31'h0, recog_bit};
      3'h6: r = {{8{acc_raw[23]}}, acc_raw};
      default: r = 32'h0;
    endcase
    data_o = r;
  end

endmodule
