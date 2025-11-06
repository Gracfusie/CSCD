//--------------------------- demux ---------------------------//
// author   : Zhan Chen
// date     : 2025-10-16
// lastEdit : 2025-10-16
// describe : Parameterized Demultiplexer (1-to-N Demux)


module pe_demux #(
    parameter DATA_WIDTH = 8,
    parameter DATA_DEPTH = 33,
    parameter SEL_WIDTH  = $clog2(DATA_DEPTH)
) (
    input  logic [DATA_WIDTH-1:0] data_in,
    input  logic [SEL_WIDTH-1:0]  sel,
    input  logic                  en,
    output logic [DATA_DEPTH*DATA_WIDTH-1:0] data_out
);

    always_comb begin
        for (int i = 0; i < DATA_DEPTH; i++) begin
            if (en && (i == sel)) begin
                data_out[(i+1)*DATA_WIDTH-1 -: DATA_WIDTH] = data_in;
            end else begin
                data_out[(i+1)*DATA_WIDTH-1 -: DATA_WIDTH] = '0;
            end
        end
    end

endmodule