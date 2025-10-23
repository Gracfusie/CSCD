// Async RAM for reading and writing data
// Constraint 1: 8 <= DATA_WIDTH <= 256
// Constraint 2: space per RAM instance <= 1Mb
// Default: DATA_WIDTH = 32, ADDR_WIDTH = 16 (with the MSB bit unused)
// Storage: 32 bit/word * 2^(16-1) words = 2^20 bit = 1Mb

// There is no constraint for the input and result memory
// Default: DATA_WIDTH = 8, ADDR_WIDTH = 20
// Storage: 8 bit/word * 2^20 words = 2^23 bit = 8Mb
// Since each matrix is 2Mb, the input takes up 8Mb space in total
// and the output 2Mb; therefore, only the first 18 bits in the
// output memory address are meaningful

module ram #(
    parameter integer DATA_WIDTH = 64,
    parameter integer ADDR_WIDTH = 23
) (
    //--------------Input ports-----------------------
    input                  clk,      // Clock input
    input [ADDR_WIDTH-1:0] address,  // Address input
    input                  cs,       // Chip select
    input                  web,      // Write enable / read enable, low active

    //--------------Inout Ports-----------------------
    input  [DATA_WIDTH-1:0] d,  // Data input,
    output [DATA_WIDTH-1:0] q   // Data output
);


  //--------------Internal variables----------------
  localparam integer RamDepth = 1 << ADDR_WIDTH;
  reg signed [DATA_WIDTH-1:0] mem[RamDepth]; // Generate mem[RamDepth][DATA_WIDTH4]
  reg [DATA_WIDTH-1:0] data_out;

  //--------------Core function---------------------
  // Tri-State buffer control
  // Output : when web = 1, oe = 1, cs = 1
  assign q = (cs) ? data_out : 'bz;

  // Memory write block
  // Write operation : when web = 0, cs = 1
  always @(posedge clk) begin : MEM_WRITE
    if (cs && ~web) begin
      mem[address] = d;
    end
  end

  // Memory read block
  // Read operation : when web = 1, oe = 1, cs = 1
  always @(posedge clk) begin : MEM_READ
    if (cs && web) begin
      data_out = mem[address];
    end
  end

endmodule
