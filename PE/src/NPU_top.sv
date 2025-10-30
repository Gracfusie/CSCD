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
  parameter int BUFFER_DEPTH = (N+1)*K_SIZE;
  logic [DATA_WIDTH-1:0] npu_buffer [BUFFER_DEPTH-1:0];

  // Write demux
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

  binary_decoder #(
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
  

endmodule
