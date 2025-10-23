module sram_ff #(
    parameter AddrWidth = 11,
    parameter DataWidth = 32
)(
    input wire                      clk_i;
    input wire                      req_i;
    input wire [3:0]                wen_i;
    input wire [AddrWidth-1:0]      addr_i,
    input wire [DataWidth-1:0]      data_i;
    output wire [DataWidth-1:0]     data_o;
);

    reg [DataWidth-1:0] memory [0:(1<<AddrWidth)-1];
    reg [DataWidth-1:0] data_out_reg;

    assign data_o = data_out_reg;

    always @(posedge clk_i) begin
        if (req_i) begin
            // Read
            data_out_reg <= memory[addr_i];

            // Write
            if (wen_i[0]) memory[addr_i][7:0]   <= data_i[7:0];
            if (wen_i[1]) memory[addr_i][15:8]  <= data_i[15:8];
            if (wen_i[2]) memory[addr_i][23:16] <= data_i[23:16];
            if (wen_i[3]) memory[addr_i][31:24] <= data_i[31:24];
        end
    end

endmodule