//--------------------------- demux ---------------------------//
// author   : Zhan Chen
// date     : 2025-10-16
// lastEdit : 2025-10-16
// describe : Parameterized Demultiplexer (1-to-N Demux)


module demux #(
    parameter DATA_WIDTH = 8,
    parameter DATA_DEPTH = 33,
    parameter SEL_WIDTH  = $clog2(DATA_DEPTH)
) (
    input  logic [DATA_WIDTH-1:0] data_in,
    input  logic [SEL_WIDTH-1:0]  sel,
    input  logic                  en,
    output logic [DATA_WIDTH-1:0] data_out [DATA_DEPTH-1:0]
);

    localparam NUM_OUTPUTS = 1 << SEL_WIDTH;

    always_comb begin
        for (int i = 0; i < NUM_OUTPUTS; i++) begin
            if (en && (i == sel)) begin
                data_out[i] = data_in;
            end else begin
                data_out[i] = '0;
            end
        end
    end

endmodule