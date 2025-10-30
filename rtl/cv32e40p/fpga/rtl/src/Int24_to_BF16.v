module Int24_to_BF16 (
    input signed [23:0] int24,
    output reg [15:0] bf16
);
    reg [4:0] exponent;
    reg [9:0] mantissa;
    reg [23:0] abs_value;
    reg sign;
    integer msb;

    always @(*) begin
        
        
        // Get the sign bit
        sign = int24[23];

        // Get the absolute value
        if (sign) begin
            abs_value = -int24;
        end else begin
            abs_value = int24;
        end

        // Handle zero case
        if (abs_value == 0) begin
            bf16 = 16'b0;  // Zero in FP16
        end else begin
            // Find the position of the most significant bit
            
            msb = 23;
            while (msb >= 0 && abs_value[msb] == 0) begin
                msb = msb - 1;
            end

            // Calculate exponent and mantissa
            exponent = msb + 1; 
           
             
                // Shift the value left to fit into the mantissa (10 bits)

            if (msb >= 11 ) begin
                mantissa = abs_value >> (msb - 10);
            end else begin
                mantissa = abs_value << (10 - msb);
            end
            

            // Construct the FP16 value
            bf16 = {sign, exponent, mantissa};
        end
    end
endmodule