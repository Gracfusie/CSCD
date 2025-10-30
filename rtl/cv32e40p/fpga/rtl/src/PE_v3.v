
module  PE(
    clk,
    rst,
    left,
    up,
    down,
    right,
    sum_out
);

    input clk;
    input rst;
    input [7:0] left;
    input [7:0] up;
    output reg [7:0] down;
    output reg [7:0] right;
    output reg [15:0] sum_out;

    always @(posedge clk or posedge rst) begin
        if(rst)begin
            right<=0;
            down<=0;
            sum_out<=0;
        end
        else begin
            down <= up;
            right <= left;
            //if(^left === 1'bx || ^up === 1'bx)begin
            //    sum_out <= 0;
            //end
            sum_out <= sum_out + left[3:0] * up[3:0] ;
        end
    end
    

    
endmodule
