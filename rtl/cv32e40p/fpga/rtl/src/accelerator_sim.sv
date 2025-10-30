//accelerator.sv
module accelerator_sim (
    input logic clka,
    input logic wea,
    input logic ena,
    input logic [10:0] addra,
    input logic [31:0] dina,
    output logic [31:0] douta,
    input logic rst_ni // 异步复位，低有效
);

    // 内部寄存器
    logic [31:0] operand1;
    logic [31:0] operand2;
    
    // 地址映射
    localparam ADDR_OPERAND1 = 0;  // 操作数1的地址
    localparam ADDR_OPERAND2 = 1;  // 操作数2的地址
    localparam ADDR_RESULT   = 2;  // 结果地址
    
    // 写入和计算逻辑
    always_ff @(posedge clka or negedge rst_ni) begin
        if (!rst_ni) begin
            operand1 <= 32'b0;
            operand2 <= 32'b0;
        end else begin
            // 写入操作数
            if (ena && wea) begin
                case (addra)
                    ADDR_OPERAND1: operand1 <= dina;
                    ADDR_OPERAND2: operand2 <= dina;
                endcase
            end
            
            // 执行加法计算（组合逻辑，但用寄存器存储结果）
            if (ena && !wea) begin
                case (addra)
                    ADDR_RESULT: douta <= operand1 + operand2;
                endcase
            end
        end
    end

endmodule

