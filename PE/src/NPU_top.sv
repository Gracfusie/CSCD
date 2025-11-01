// -----------------------------------------------------------------------------
// Memory-like top wrapper for the PE core.
// - 32-bit word port matches the simple SRAM-like slave used in the lab setup.
// - No wait states; reads return registered data in 1 cycle.
// Map this block to a base address (e.g., 0x7000_0000) via the AXI crossbar,
// and bridge with axi2mem like SRAM (see lab example).  :contentReference[oaicite:3]{index=3}
// -----------------------------------------------------------------------------
module NPU_top #(
  parameter int N = 10,
  parameter int K_SIZE = 3,
  parameter int DATA_WIDTH = 8,
  parameter int AXI_WIDTH = 32,
  parameter int ADDR_W = 3  // enough for 0..4
) (
  input  logic               clk,
  input  logic               reset,        // high-active

  // SRAM-like memory port (compatible with axi2mem style)
  input  logic               req_i,        // access qualifier (assume always 1'b1 OK)
  input  logic [3:0]         wen_i,        // byte enables; write if any bit=1
  input  logic [ADDR_W-1:0]  addr_i,       // word index (offset / 4)
  input  logic [AXI_WIDTH-1:0]        wdata_i,
  output logic [AXI_WIDTH-1:0]        rdata_o
);

  // NPU buffer
  parameter int BUFFER_DEPTH = (2*N+1)*K_SIZE; // 63
  logic [K_SIZE*DATA_WIDTH-1:0] npu_buffer [BUFFER_DEPTH-1:0];
  wire [DATA_WIDTH-1:0] npu_buffer_flattened [K_SIZE*BUFFER_DEPTH-1:0];
  assign npu_buffer_flattened = npu_buffer;

  // Write demux
  // (0-9)*9 for weights, (10-19)*9 for direct inputs, 20*9 for broadcast inputs
  wire [DATA_WIDTH-1:0] npu_buffer_wdata [BUFFER_DEPTH-1:0];
  wire [BUFFER_DEPTH-1:0] npu_buffer_wen;

  pe_demux #(
    .DATA_WIDTH (K_SIZE*DATA_WIDTH),
    .DATA_DEPTH (BUFFER_DEPTH),
    .SEL_WIDTH  ($clog2(BUFFER_DEPTH))
  ) u_demux (
    .data_in (wdata_i[K_SIZE*DATA_WIDTH-1:0]),
    .sel     (addr_i[ADDR_W-1:0]),
    .en      (|wen_i),
    .data_out(npu_buffer_wdata)
  );

  pe_binary_decoder #(
    .ADDR_WIDTH($clog2(BUFFER_DEPTH))
  ) u_decoder (
    .addr(),
    .en(|wen_i),
    .y(npu_buffer_wen)
  );

  always @(posedge clk or posedge reset) begin
    if (reset) begin
      npu_buffer <= '0;
      rdata_o <= '0;
    end else begin
      // Write operation
      for (int i = 0; i < BUFFER_DEPTH; i++) begin
        if (npu_buffer_wen[i]) begin
          npu_buffer[i] <= npu_buffer_wdata[i];
        end
      end
    end    
  end

  // Read mux
  wire [DATA_WIDTH-1:0] a_mul [N-1:0];
  wire [DATA_WIDTH-1:0] b_mul [N-1:0];

  generate
    for (genvar i = 0; i < N; i++) begin : PE_MUX_GEN_WEIGHT
      pe_mux #(
        .WIDTH(DATA_WIDTH),
        .DEPTH(K_SIZE*K_SIZE),
        .SEL_WIDTH($clog2(K_SIZE*K_SIZE))
      ) u_pe_mux (
        .data_in (npu_buffer_flattened[i*K_SIZE*K_SIZE +: K_SIZE*K_SIZE]),
        .sel     (),
        .data_out(a_mul[i])
      );
    end
  endgenerate

  generate
    for (genvar i = 0; i < N; i++) begin : PE_MUX_GEN_INPUT
      pe_mux #(
        .WIDTH(DATA_WIDTH),
        .DEPTH(K_SIZE*K_SIZE*2),
        .SEL_WIDTH($clog2(K_SIZE*K_SIZE*2))
      ) u_pe_mux (
        .data_in ({npu_buffer_flattened[(N+i)*K_SIZE*K_SIZE +: K_SIZE*K_SIZE], npu_buffer_flattened[2*N*K_SIZE*K_SIZE +: K_SIZE*K_SIZE]}),
        .sel     (),
        .data_out(b_mul[i])
      );
    end
  endgenerate

  // PE cores
  generate
    for (genvar i = 0; i < N; i++) begin: PE_CORE_GEN
      pe_core #(
        .W_IN(DATA_WIDTH),
        .W_MUL(2*DATA_WIDTH),
        .W_ACC(3*DATA_WIDTH)
      ) u_pe_core (
        .clk     (clk),
        .reset   (reset),
        .pe_en   (),
        .mode_sel(),
        .reg_reset(),
        .a_in    (a_mul[i]),
        .b_in    (b_mul[i]),
        .results()
      );
    end
  endgenerate



endmodule
