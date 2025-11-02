//--------------------------- binary_decoder ---------------------------//
// author   : Zhan Chen
// date     : 2025-10-16
// lastEdit : 2025-10-16
// describe : From Binary to One-Hot, Parameterized.

module pe_binary_decoder #(
    parameter ADDR_WIDTH = 3,  // N-bit address => 2^N outputs
    parameter DEPTH = (1 << ADDR_WIDTH)
) (
    input  logic [ADDR_WIDTH-1:0] addr,
    input  logic                  en,
    output logic [DEPTH-1:0] y  // y[0] to y[2^N - 1]
);

    always_comb begin
        y = '0; 
        if (en) begin
            y[addr] = 1'b1;
        end
    end

endmodule
