module adder_tree #(
    parameter int N              = 10,
    parameter int DATA_IN_WIDTH  = 24,
    parameter int DATA_OUT_WIDTH = 8,
    parameter int ACC_WIDTH      = 32
)(
    input  logic signed [DATA_IN_WIDTH-1:0] data_in [0:N-1],
    output logic [DATA_OUT_WIDTH-1:0]       data_out
);

    // 32-bit accumulator to prevent overflow
    logic signed [ACC_WIDTH-1:0] sum;
    logic [ACC_WIDTH-1:0]        relu_out;

    // Combinational calculation
    always_comb begin
        sum = 0;

        // Accumulate 10 signed numbers
        for (int i = 0; i < N; i++) begin
            sum += data_in[i];
        end

        // ReLU activation
        if (sum < 0)
            relu_out = 0;
        else
            relu_out = sum;

        // Take lowest 8 bits after ReLU
        data_out = relu_out[DATA_OUT_WIDTH-1:0];
    end

endmodule
