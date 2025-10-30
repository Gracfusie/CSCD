//--------------------------- mux ---------------------------//
// author   : Grok Code Fast 1
// date     : 2025-10-28
// lastEdit : 2025-10-28
// describe : Parameterized multiplexer, selects one of multiple inputs based on select signal.

module pe_mux #(
    parameter WIDTH = 8,      // Data width
    parameter DEPTH = 8,      // Number of inputs
    parameter SEL_WIDTH = $clog2(DEPTH)   // Select signal width, supports 2^SEL_WIDTH inputs
) (
    input  logic [WIDTH-1:0] data_in [DEPTH-1:0],  // Input data array
    input  logic [SEL_WIDTH-1:0] sel,                       // Select signal
    output logic [WIDTH-1:0] data_out                       // Selected output
);

    always_comb begin
        data_out = data_in[sel];
    end

endmodule
