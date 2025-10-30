// // -----------------------------------------------------------------------------
// // Parametric 2:1 MUX (signed data)
// // -----------------------------------------------------------------------------
// module pe_mux #(
//   parameter int W = 24
// ) (
//   input  logic              sel,       // 0: a (raw), 1: b (activated)
//   input  logic signed [W-1:0] a,
//   input  logic signed [W-1:0] b,
//   output logic signed [W-1:0] y
// );
//   always_comb begin
//     y = sel ? b : a;
//   end
// endmodule

//--------------------------- mux ---------------------------//
// author   : Grok Code Fast 1
// date     : 2025-10-28
// lastEdit : 2025-10-28
// describe : Parameterized multiplexer, selects one of multiple inputs based on select signal.

module mux #(
    parameter WIDTH = 8,      // Data width
    parameter SEL_WIDTH = 3   // Select signal width, supports 2^SEL_WIDTH inputs
) (
    input  logic [WIDTH-1:0] data_in [(1<<SEL_WIDTH)-1:0],  // Input data array
    input  logic [SEL_WIDTH-1:0] sel,                       // Select signal
    output logic [WIDTH-1:0] data_out                       // Selected output
);

    always_comb begin
        data_out = data_in[sel];
    end

endmodule
