// -----------------------------------------------------------------------------
// PE accelerator with memory-like interface
// Bus-side ports mirror the course SRAM-like style used in the PDF lab:
//   req_i, wen_i[3:0], addr_i, data_i, data_o
// You can connect this behind the same axi2mem bridge used for SRAM.
// -----------------------------------------------------------------------------
module pe_accel #(
  parameter int ADDR_WIDTH = 2  // 4 word locations: 0..3
)(
  input  logic                   clk_i,
  input  logic                   rst_i,         // active high

  // "SRAM-like" interface (word addressed, 32-bit data)
  input  logic                   req_i,         // access enable
  input  logic [3:0]             wen_i,         // byte write enables (any non-zero => write)
  input  logic [ADDR_WIDTH-1:0]  addr_i,        // word address
  input  logic [31:0]            data_i,        // write data
  output logic [31:0]            data_o         // read data
);

  // ---------------------------------------------------------
  // Internal registers exposed via the address map
  // ---------------------------------------------------------
  localparam int A_ADDR    = 0;   // write a[7:0]
  localparam int B_ADDR    = 1;   // write b[7:0] (signed)
  localparam int CTRL_ADDR = 2;   // ctrl/status
  localparam int RES_ADDR  = 3;   // result

  logic        mode_sel_q;
  logic        start_pulse;       // 1-cycle pulse derived from CTRL write bit0
  logic        clr_acc_pulse;     // 1-cycle pulse from CTRL write bit2

  logic [7:0]               a_q;
  logic signed [7:0]        b_q;
  logic                     out_vld;
  logic signed [23:0]       pro_sum;

  // Compute core
  pe_core u_core (
    .clk     (clk_i),
    .reset   (rst_i),
    .read_in (start_pulse),
    .mode_sel(mode_sel_q),
    .a_mul   (a_q),
    .b_mul   (b_q),
    .clr_acc (clr_acc_pulse),
    .out_vld (out_vld),
    .pro_sum (pro_sum)
  );

  // ---------------------------------------------------------
  // Write path (byte enables honored, but only low byte used)
  // ---------------------------------------------------------
  // One-cycle pulses from writes to CTRL
  logic start_req, clr_req;

  // Snoop writes when req_i && (wen_i != 0)
  wire do_write = req_i & (|wen_i);

  always_ff @(posedge clk_i or posedge rst_i) begin
    if (rst_i) begin
      a_q          <= 8'h00;
      b_q          <= 8'sh00;
      mode_sel_q   <= 1'b0;
      start_req    <= 1'b0;
      clr_req      <= 1'b0;
    end else begin
      start_req  <= 1'b0;
      clr_req    <= 1'b0;

      if (do_write) begin
        unique case (addr_i)
          A_ADDR: begin
            if (wen_i[0]) a_q <= data_i[7:0];
          end
          B_ADDR: begin
            if (wen_i[0]) b_q <= data_i[7:0];
          end
          CTRL_ADDR: begin
            // [1] persists (mode_sel), [0] and [2] are pulse (start/clear)
            if (wen_i[0]) begin
              mode_sel_q <= data_i[1];
              if (data_i[0]) start_req <= 1'b1;
              if (data_i[2]) clr_req   <= 1'b1;
            end
          end
          default: /* no-op */;
        endcase
      end
    end
  end

  // Generate single-cycle pulses (safe if bus holds CTRL value for 1+ cycles)
  assign start_pulse   = start_req;
  assign clr_acc_pulse = clr_req;

  // ---------------------------------------------------------
  // Read path
  //   - RES returns sign-extended 24-bit result in [23:0]
  //   - CTRL returns control + status (bit8=out_vld)
  // ---------------------------------------------------------
  always_comb begin
    logic [31:0] r = 32'h0;

    unique case (addr_i)
      A_ADDR:    r = {24'h0, a_q};
      B_ADDR:    r = {24'h0, b_q[7:0]};  // raw view
      CTRL_ADDR: r = {23'h0, out_vld, 5'h0, mode_sel_q, 1'b0, 1'b0}; // [8]=out_vld
      RES_ADDR:  r = {{8{pro_sum[23]}}, pro_sum};                     // sign-extend
      default:   r = 32'h0;
    endcase

    data_o = r;
  end

endmodule
