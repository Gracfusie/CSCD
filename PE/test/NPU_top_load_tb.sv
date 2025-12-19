`timescale 1ns/1ps
`define T 10 // Clock period in ns

module NPU_top_load_tb;

  // Parameters
  localparam int N = 10;
  localparam int K_SIZE = 3;
  localparam int DATA_WIDTH = 8;
  localparam int AXI_WIDTH = 32;
  localparam int ADDR_W = 3;

  // DUT IO
  logic                 clk;
  logic                 rst_n;
  logic                 req_i;
  logic [3:0]           wen_i;
  logic [ADDR_W-1:0]    addr_i;
  logic [AXI_WIDTH-1:0] wdata_i;
  logic [AXI_WIDTH-1:0] rdata_o;

  // assign wen_i = {4{wdata_i[AXI_WIDTH-1]}}; // replicate for all bytes

  // Testbench signals
  // logic [DATA_WIDTH-1:0] instr;
  // logic [DATA_WIDTH-1:0] load_data_1;
  // logic [DATA_WIDTH-1:0] load_data_2;
  // logic [DATA_WIDTH-1:0] load_data_3;

  // logic       reuse;
  // logic [1:0] write_back_mode;
  // logic       relu_en;
  // logic       broadcast_en;
  // logic [1:0] load_mode; 

  // assign instr = {1'b0, reuse, write_back_mode, relu_en, broadcast_en, load_mode};
  // assign wdata_i = {instr, load_data_1, load_data_2, load_data_3};

  logic [K_SIZE*DATA_WIDTH-1:0] buffer_word;
  logic [DATA_WIDTH-1:0] segment;
  string segment_str;

  // Clock generation
  initial clk = 0;
  always #(`T/2) clk = ~clk;

  // Instantiate DUT
  NPU_top #(
    .N(N),
    .K_SIZE(K_SIZE),
    .DATA_WIDTH(DATA_WIDTH),
    .AXI_WIDTH(AXI_WIDTH),
    .ADDR_W(ADDR_W)
  ) dut (
    .clk(clk),
    .rst_n(rst_n),
    .req_i(req_i),
    .wen_i(wen_i),
    .addr_i(addr_i),
    .wdata_i(wdata_i),
    .rdata_o(rdata_o)
  );

  int fd, rdata;
  string filename, line;

  // Test procedure
  initial begin
    // -------- FSDB dump for Verdi --------
    $fsdbDumpfile("waveform.fsdb");
    $fsdbDumpvars(0, NPU_top_load_tb);

    // Initialize
    rst_n = 0;
    req_i = 1;
    wen_i = 4'b0000;
    addr_i = 0;
    // // wdata_i = 0;
    // // instr = 0;
    // reuse = 0;
    // write_back_mode = 2'b11;
    // relu_en = 0;
    // broadcast_en = 0;
    // load_mode = 2'b00;
    // load_data_1 = 0;
    // load_data_2 = 0;
    // load_data_3 = 0;
    wdata_i = 32'b00110000_00000000_00000000_00000000;

    // Reset
    #(`T*2);
    rst_n = 1;
    #(`T);

    filename = "../../PE/test/python/npu/wdata_input_3598.txt";
    fd = $fopen(filename, "r");
    if (fd == 0) begin
      $display("Failed to open file: %s", filename);
      $finish;
    end
    while (!$feof(fd)) begin
      line = "";
      rdata = $fgets(line, fd);
      if (rdata > 0) begin
        @(negedge clk);
        $sscanf(line, "%b", wdata_i);
        wen_i = 4'b1111;
        @(negedge clk);
        wen_i = 4'b0000;
        repeat (6) @(negedge clk);
      end
    end
    $fclose(fd);
    
    @(negedge clk);
    wdata_i = 32'b00110000_00000000_00000000_00000000;
    repeat (10) @(negedge clk);

    $finish;
  end

  initial begin : record_rdata
    integer fd;
    string filename;
    string rdata_str;
    filename = "../../PE/test/python/npu/rdata_output.txt";
    fd = $fopen(filename, "w");
    while (1) begin
      @(posedge clk);
      if ((wdata_i[31] == 1'b0) && (wdata_i[27:26] != 2'b00) && wen_i[3]) begin
        @(negedge clk);
        rdata_str = $sformatf("%0b", dut.rdata_o[AXI_WIDTH-1:0]);
        while (rdata_str.len() < AXI_WIDTH)
            rdata_str = {"0", rdata_str};
        $fwrite(fd, "%s\n", rdata_str);
      end
    end
    $fclose(fd);
  end

endmodule
