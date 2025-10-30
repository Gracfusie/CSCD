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

  

endmodule
