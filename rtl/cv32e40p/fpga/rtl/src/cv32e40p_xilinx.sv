`include "axi/typedef.svh"
`include "axi/assign.svh"

module cv32e40p_xilinx (
    input   logic   clk_i,
    input   logic   rst_ni,
    input   logic   tck_i,
    input   logic   tms_i,
    input   logic   td_i,
    output  logic   td_o,
    output  logic   clk_led,
    output  logic   tck_led
);
    /*logic clk_i;
    always_ff @(posedge fpga_clk_i) begin 
        if(~rst_ni) begin
            clk_i <= 0;
        end
        else begin
        clk_i <= ~clk_i;
        end
    end*/

    logic ndmreset;
    logic ndmreset_n;

    rstgen i_rstgen_main (
        .clk_i        ( clk_i                      ),
        .rst_ni       ( rst_ni & (~ndmreset) ),
        .test_mode_i  ( 1'b0                  ),
        .rst_no       ( ndmreset_n               ),
        .init_no      (                          ) // keep open
    );

    //--------------------------- master & slave definition ---------------------------//

    parameter SLAVE_NUM = 5;
    parameter MASTER_NUM = 3;
    parameter ID_WIDTH = $clog2(MASTER_NUM) + $clog2(SLAVE_NUM);

    AXI_BUS #(
        .AXI_ADDR_WIDTH ( 32    ),
            // AXI 总线的地址宽度
        .AXI_DATA_WIDTH ( 32    ),
            // AXI 总线的数据宽度
        .AXI_ID_WIDTH   ( $clog2(MASTER_NUM)     ),
        .AXI_USER_WIDTH ( 1     )
            // 设计中不考虑 User
    ) slave[MASTER_NUM-1:0]();
    // 在Master看来，AXI总线是它的slave. 设计中有3个master：[0]CPU-Instruction [1]CPU-Data [2]Debug Module，因此 ID_WIDTH = 2.
    // CPU 对指令和数据的访问是分开的。

    AXI_BUS #(
        .AXI_ADDR_WIDTH ( 32    ),
        .AXI_DATA_WIDTH ( 32    ),
        .AXI_ID_WIDTH   ( $clog2(SLAVE_NUM)+$clog2(MASTER_NUM)     ),
            // ID位宽是：master需要的ID加上slave需要的ID
        .AXI_USER_WIDTH ( 1     )
    ) master[SLAVE_NUM-1:0]();//new slave: accelerator
    // 在Slave看来，AXI总线是它的master. 设计中有5个slave: 
    // [0]BootROM [1]SRAM(ICache) [2]DebugROM [3]SRAM(DCache) [4] Accelerator

    // AXI_BUS 是 sv 的接口 interface 类型，封装 AXI 总线协议的信号集合。

    //--------------------------- Xbar instantialize ---------------------------//

    localparam axi_pkg::xbar_cfg_t AXI_XBAR_CFG = '{
        NoSlvPorts:         MASTER_NUM, // num of MASTER
        NoMstPorts:         SLAVE_NUM, // num of SLAVE
        // new slave: accelerator
        MaxMstTrans:        1, // Probably requires update
        MaxSlvTrans:        1, // Probably requires update
        FallThrough:        1'b0,
        LatencyMode:        axi_pkg::CUT_ALL_PORTS,
        AxiIdWidthSlvPorts: $clog2(MASTER_NUM), // MASTER ID width
        AxiIdUsedSlvPorts:  $clog2(MASTER_NUM), // MASTER ID width
        UniqueIds:          1'b0,
        AxiAddrWidth:       32,
        AxiDataWidth:       32,
        NoAddrRules:        SLAVE_NUM  // num of SLAVE
        // new slave: accelerator
    };

    axi_pkg::xbar_rule_32_t [SLAVE_NUM-1:0] addr_map;
    // 定义地址映射的规则，num of SLAVE

    localparam idx_rom      = 0;
    localparam idx_srami    = 1;
    localparam idx_debug    = 2;
    localparam idx_sramd    = 3;
    localparam idx_acc      = 4;
    localparam rom_base     = 32'h0001_0000;
    localparam rom_length   = 32'h0001_0000; // 64KB Boot ROM
    localparam srami_base   = 32'h8000_0000;
    localparam srami_length = 32'h0000_2000; // SRAM have 8KB, 4B/word, 2048 words
    localparam debug_base   = 32'h0000_0000;
    localparam debug_length = 32'h0000_1000;
    localparam sramd_base   = 32'h8100_0000;
    localparam sramd_length = 32'h0000_2000;
    localparam acc_base     = 32'h7000_0000;// new slave: accelerator
    localparam acc_length   = 32'h1000_0000;// new slave: accelerator

    assign addr_map = '{
        '{ idx: idx_rom,       start_addr: rom_base,        end_addr: rom_base + rom_length   },
        '{ idx: idx_srami,     start_addr: srami_base,      end_addr: srami_base + srami_length },
        '{ idx: idx_debug,     start_addr: debug_base,      end_addr: debug_base + debug_length },
        '{ idx: idx_sramd,     start_addr: sramd_base,      end_addr: sramd_base + sramd_length },
        '{ idx: idx_acc,       start_addr: acc_base,        end_addr: acc_base + acc_length }
    };

    axi_xbar_intf #(
        .AXI_USER_WIDTH ( 1                         ),
        .Cfg            ( AXI_XBAR_CFG              ),
        .rule_t         ( axi_pkg::xbar_rule_32_t   )
    ) i_axi_xbar (
        .clk_i                 ( clk_i      ),
        .rst_ni                ( ndmreset_n ),
        .test_i                ( 1'b0       ),
        .slv_ports             ( slave      ), // define above
        .mst_ports             ( master     ), // define above
        .addr_map_i            ( addr_map   ), // define above
        .en_default_mst_port_i ( '0         ),
        .default_mst_port_i    ( '0         )
    );

    //--------------------------- Master Slave Connection ---------------------------//

    logic           instr_req;
    logic           instr_gnt;
    logic           instr_rvalid;
    logic [31:0]    instr_addr;
    logic [31:0]    instr_rdata;
    logic           data_req;
    logic           data_gnt;
    logic           data_rvalid;
    logic           data_we;
    logic [3:0]     data_be;
    logic [31:0]    data_addr;
    logic [31:0]    data_wdata;
    logic [31:0]    data_rdata;
    logic           data_valid;
    logic           debug_req_valid;
    logic           debug_req_ready;
    dm::dmi_req_t   debug_req;
    logic           debug_resp_valid;
    logic           debug_resp_ready;
    dm::dmi_resp_t  debug_resp;
    logic           debug_req_irq;

    cv32e40p_top #(
        .COREV_PULP(0),
        .COREV_CLUSTER(0),
        .FPU(0),
        .FPU_ADDMUL_LAT(0),
        .FPU_OTHERS_LAT(0),
        .ZFINX(0),
        .NUM_MHPMCOUNTERS(0) 
    )   i_ri5cy (
        .clk_i                  (clk_i          ),
        .rst_ni                 (ndmreset_n     ),
        .pulp_clock_en_i        ('0             ),
        .scan_cg_en_i           ('0             ),
        .boot_addr_i            (32'h00010000   ),
        .mtvec_addr_i           (32'h00010000   ),
        .dm_halt_addr_i         (32'h00000800   ),
        .hart_id_i              ('0             ),
        .dm_exception_addr_i    (32'h00010000   ),
        .instr_req_o            (instr_req      ),
        .instr_gnt_i            (instr_gnt      ),
        .instr_rvalid_i         (instr_rvalid   ),
        .instr_addr_o           (instr_addr     ),
        .instr_rdata_i          (instr_rdata    ),
        .data_req_o             (data_req       ),
        .data_gnt_i             (data_gnt       ),
        .data_rvalid_i          (data_valid     ),//data_rvalid process both rvalid&wvalid
        .data_we_o              (data_we        ),
        .data_be_o              (data_be        ),
        .data_addr_o            (data_addr      ),
        .data_wdata_o           (data_wdata     ),
        .data_rdata_i           (data_rdata     ),
        .irq_i                  (32'b0          ),
        .irq_ack_o              (               ),
        .irq_id_o               (               ),
        .debug_req_i            (debug_req_irq  ),
        .debug_havereset_o      (               ),
        .debug_running_o        (               ),
        .debug_halted_o         (               ),
        .fetch_enable_i         (1'b1           ),
        .core_sleep_o           (               )
    );

    `AXI_TYPEDEF_ALL(axi        ,
                logic [31:0]    ,
                logic [3:0]     ,
                logic [31:0]    ,
                logic [3:0]     ,
                logic           )

    axi_req_t   instr_axi_req;
    axi_resp_t  instr_axi_resp;

    `AXI_ASSIGN_FROM_REQ(slave[0],instr_axi_req)
    `AXI_ASSIGN_TO_RESP(instr_axi_resp,slave[0])

    axi_adapter #(
        .ADDR_WIDTH         (32         ),
        .DATA_WIDTH         (32         ),
        .AXI_DATA_WIDTH     (32         ),
        .AXI_ID_WIDTH       (ID_WIDTH          ),
        .MAX_OUTSTANDING_AW (7          ),
        .axi_req_t          (axi_req_t  ),
        .axi_rsp_t          (axi_resp_t )
    ) i_axi_adapter_instr (
        .clk_i                 ( clk_i          ),
        .rst_ni                ( ndmreset_n     ),
        .req_i                 ( instr_req      ),
        .type_i                ( 1'b0           ),
        .amo_i                 ( 4'b0000        ),
        .gnt_o                 ( instr_gnt      ),
        .addr_i                ( instr_addr     ),
        .we_i                  ( 1'b0           ),
        .wdata_i               ( '0             ),
        .be_i                  ( 4'b1111        ),
        .size_i                ( 2'b10          ),
        .id_i                  ( 5'b00001          ),
        .valid_o               ( instr_rvalid   ),
        .rdata_o               ( instr_rdata    ),
        .id_o                  (                ),
        .critical_word_o       (                ),
        .critical_word_valid_o (                ),
        .axi_req_o             ( instr_axi_req  ),
        .axi_resp_i            ( instr_axi_resp )
    );

    axi_req_t   data_axi_req;
    axi_resp_t  data_axi_resp;

    `AXI_ASSIGN_FROM_REQ(slave[1],data_axi_req)
    `AXI_ASSIGN_TO_RESP(data_axi_resp,slave[1])

    assign data_valid = data_rvalid | data_axi_resp.b_valid;

    axi_adapter #(
        .ADDR_WIDTH         (32         ),
        .DATA_WIDTH         (32         ),
        .AXI_DATA_WIDTH     (32         ),
        .AXI_ID_WIDTH       (ID_WIDTH          ),
        .MAX_OUTSTANDING_AW (7          ),
        .axi_req_t          (axi_req_t  ),
        .axi_rsp_t          (axi_resp_t )
    ) i_axi_adapter_data (
        .clk_i                 ( clk_i          ),
        .rst_ni                ( ndmreset_n     ),
        .req_i                 ( data_req       ),
        .type_i                ( 1'b0           ),
        .amo_i                 ( 4'b0000        ),
        .gnt_o                 ( data_gnt       ),
        .addr_i                ( data_addr      ),
        .we_i                  ( data_we        ),
        .wdata_i               ( data_wdata     ),
        .be_i                  ( data_be        ),
        .size_i                ( 2'b10          ),
        .id_i                  ( 5'b00010          ),
        .valid_o               ( data_rvalid    ),
        .rdata_o               ( data_rdata     ),
        .id_o                  (                ),
        .critical_word_o       (                ),
        .critical_word_valid_o (                ),
        .axi_req_o             ( data_axi_req   ),
        .axi_resp_i            ( data_axi_resp  )
    );

    dmi_jtag i_dmi_jtag (
        .clk_i                ( clk_i               ),
        .rst_ni               ( rst_ni              ),
        .dmi_rst_no           (                     ), // keep open
        .testmode_i           ( 1'b0                ),
        .dmi_req_valid_o      ( debug_req_valid     ),
        .dmi_req_ready_i      ( debug_req_ready     ),
        .dmi_req_o            ( debug_req           ),
        .dmi_resp_valid_i     ( debug_resp_valid    ),
        .dmi_resp_ready_o     ( debug_resp_ready    ),
        .dmi_resp_i           ( debug_resp          ),
        .tck_i                ( tck_i               ),
        .tms_i                ( tms_i               ),
        .trst_ni              ( rst_ni             ),
        .td_i                 ( td_i                ),
        .td_o                 ( td_o                ),
        .tdo_oe_o             (                     )
    );

    dm::hartinfo_t hartinfo;
    assign hartinfo = '{
        zero1       : '0,
        nscratch    : 2,
        zero0       : '0,
        dataaccess  : 1'b1,
        datasize    : dm::DataCount,
        dataaddr    : dm::DataAddr
    };

    logic           dm_slave_req;
    logic           dm_slave_we;
    logic [31:0]    dm_slave_addr;
    logic [3:0]     dm_slave_be;
    logic [31:0]    dm_slave_wdata;
    logic [31:0]    dm_slave_rdata;

    logic           dm_master_req;
    logic [31:0]    dm_master_add;
    logic           dm_master_we;
    logic [31:0]    dm_master_wdata;
    logic [3:0]     dm_master_be;
    logic           dm_master_gnt;
    logic           dm_master_r_valid;
    logic [31:0]    dm_master_r_rdata;

    axi2mem #(
        .AXI_ID_WIDTH   ( ID_WIDTH    ),
        .AXI_ADDR_WIDTH ( 32        ),
        .AXI_DATA_WIDTH ( 32        ),
        .AXI_USER_WIDTH ( 1        )
    ) i_dm_axi2mem (
        .clk_i      ( clk_i                       ),
        .rst_ni     ( rst_ni                     ),
        .slave      ( master[idx_debug]           ),
        .req_o      ( dm_slave_req              ),
        .we_o       ( dm_slave_we               ),
        .addr_o     ( dm_slave_addr             ),
        .be_o       ( dm_slave_be               ),
        .data_o     ( dm_slave_wdata            ),
        .data_i     ( dm_slave_rdata            )
    );


    dm_top #(
        .NrHarts          ( 1       ),
        .BusWidth         ( 32      ),
        .SelectableHarts  ( 1'b1    )
    ) i_dm_top (
        .clk_i            ( clk_i               ),
        .rst_ni           ( rst_ni              ), // PoR
        .testmode_i       ( 1'b0                ),
        .ndmreset_o       ( ndmreset            ),
        .dmactive_o       (                     ), // active debug session
        .debug_req_o      ( debug_req_irq       ),
        .unavailable_i    ( '0                  ),
        .hartinfo_i       ( hartinfo            ),
        .slave_req_i      ( dm_slave_req        ),
        .slave_we_i       ( dm_slave_we         ),
        .slave_addr_i     ( dm_slave_addr       ),
        .slave_be_i       ( dm_slave_be         ),
        .slave_wdata_i    ( dm_slave_wdata      ),
        .slave_rdata_o    ( dm_slave_rdata      ),
        .master_req_o     ( dm_master_req       ),
        .master_add_o     ( dm_master_add       ),
        .master_we_o      ( dm_master_we        ),
        .master_wdata_o   ( dm_master_wdata     ),
        .master_be_o      ( dm_master_be        ),
        .master_gnt_i     ( dm_master_gnt       ),
        .master_r_valid_i ( dm_master_r_valid   ),
        .master_r_rdata_i ( dm_master_r_rdata   ),
        .dmi_rst_ni       ( rst_ni              ),
        .dmi_req_valid_i  ( debug_req_valid     ),
        .dmi_req_ready_o  ( debug_req_ready     ),
        .dmi_req_i        ( debug_req           ),
        .dmi_resp_valid_o ( debug_resp_valid    ),
        .dmi_resp_ready_i ( debug_resp_ready    ),
        .dmi_resp_o       ( debug_resp          )
    );


    axi_req_t   dm_axi_m_req;
    axi_resp_t  dm_axi_m_resp;

    axi_adapter #(
        .ADDR_WIDTH         (32         ),
        .DATA_WIDTH         (32         ),
        .AXI_DATA_WIDTH     (32         ),
        .AXI_ID_WIDTH       (ID_WIDTH          ),
        .MAX_OUTSTANDING_AW (7          ),
        .axi_req_t          (axi_req_t  ),
        .axi_rsp_t          (axi_resp_t )
    ) i_axi_adapter_dm (
        .clk_i                 ( clk_i              ),
        .rst_ni                ( rst_ni             ),
        .req_i                 ( dm_master_req      ),
        .type_i                ( 1'b0               ),
        .amo_i                 ( 4'b0000            ),
        .gnt_o                 ( dm_master_gnt      ),
        .addr_i                ( dm_master_add      ),
        .we_i                  ( dm_master_we       ),
        .wdata_i               ( dm_master_wdata    ),
        .be_i                  ( dm_master_be       ),
        .size_i                ( 2'b10              ),
        .id_i                  ( '0                 ),
        .valid_o               ( dm_master_r_valid  ),
        .rdata_o               ( dm_master_r_rdata  ),
        .id_o                  (                    ),
        .critical_word_o       (                    ),
        .critical_word_valid_o (                    ),
        .axi_req_o             ( dm_axi_m_req       ),
        .axi_resp_i            ( dm_axi_m_resp      )
    );

    `AXI_ASSIGN_FROM_REQ(slave[2], dm_axi_m_req)
    `AXI_ASSIGN_TO_RESP(dm_axi_m_resp, slave[2])

    logic           rom_req;
    logic		    rom_we;
    logic [31:0]    rom_addr;
    logic [31:0]	rom_wdata;
    logic [31:0]    rom_rdata;
    
    
    bootram i_bootram (
	.clk_i	(clk_i		),
	.rst_ni	(rst_ni		),
	.req_i	(rom_req	),
	.wen_i	(rom_we		),
	.addr_i	(rom_addr[5:2]	),
	.data_i	(rom_wdata	),
	.data_o	(rom_rdata	)
    );

    axi2mem #(
        .AXI_ID_WIDTH   ( ID_WIDTH     ),
        .AXI_ADDR_WIDTH ( 32    ),
        .AXI_DATA_WIDTH ( 32    ),
        .AXI_USER_WIDTH ( 1     )
    ) i_axi2rom (
        .clk_i  ( clk_i             ),
        .rst_ni ( ndmreset_n        ),
        .slave  ( master[idx_rom]   ),
        .req_o  ( rom_req           ),
        .we_o   ( rom_we            ),
        .addr_o ( rom_addr          ),
        .be_o   (                   ),
        .data_o ( rom_wdata         ),
        .data_i ( rom_rdata         )
    );

//--------------------------- idx_icache ---------------------------//

	logic           srami_req;
	logic           srami_we;
	logic [31:0]    srami_addr;
	logic [31:0]    srami_wdata;
	logic [3:0]     srami_be;
	logic [31:0]    srami_rdata;

    logic [3:0]     srami_wen_n;
    assign srami_wen_n = ~(srami_be & {4{srami_we}});

`ifdef SIM
    sram_ff #(
        .AddrWidth(11), // 2048 Words
        .DataWidth(32),
        .INIT_FILE("../../rtl/cv32e40p/fpga/tb/srami_mount_test.hex")
    ) i_srami (
        .clk_i  (clk_i),
        .req_i  (srami_req),
        .wen_i  (srami_be & {4{srami_we}}),
        .addr_i (srami_addr[12:2]),
        .data_i (srami_wdata),
        .data_o (srami_rdata)
    );
`else
	RA1SHD_2048x32M8 i_icache_sram (
        .Q   ( srami_rdata      ),
        .CLK ( clk_i            ),
        .CEN ( ~srami_req       ),     // low-active chip enable
        .WEN ( srami_wen_n      ),     // low-active byte write enable
        .A   ( srami_addr[12:2] ),     // word address (8KB = 2048 words)
        .D   ( srami_wdata      ),
        .OEN ( 1'b0             )      // low-active output enable, always enabled
    );	
`endif	
    axi2mem #(
        .AXI_ID_WIDTH   ( ID_WIDTH     ),
        .AXI_ADDR_WIDTH ( 32    ),
        .AXI_DATA_WIDTH ( 32    ),
        .AXI_USER_WIDTH ( 1     )
    ) i_axi2sram (
        .clk_i  ( clk_i             ),
        .rst_ni ( ndmreset_n        ),
        .slave  ( master[idx_srami] ),
        .req_o  ( srami_req         ),
        .we_o   ( srami_we          ),
        .addr_o ( srami_addr        ),
        .be_o   ( srami_be          ), // byte enable
        .data_o ( srami_wdata       ),
        .data_i ( srami_rdata       )
    );

//--------------------------- idx_dcache ---------------------------//

    logic           sramd_req;
    logic           sramd_we;
    logic [31:0]    sramd_addr;
    logic [31:0]    sramd_wdata;
    logic [3:0]     sramd_be;
    logic [31:0]    sramd_rdata;

    logic [3:0]     sramd_wen_n;
    assign sramd_wen_n = ~(sramd_be & {4{sramd_we}});
`ifdef SIM
    sram_ff #(
        .AddrWidth(11), // 2048 Words
        .DataWidth(32),
        .INIT_FILE("../../rtl/cv32e40p/fpga/tb/sramd_mount_test.hex")
    ) i_sramd (
        .clk_i  (clk_i),
        .req_i  (sramd_req),
        .wen_i  (sramd_be & {4{sramd_we}}),
        .addr_i (sramd_addr[12:2]),
        .data_i (sramd_wdata),
        .data_o (sramd_rdata)
    );
`else
    RA1SHD_2048x32M8 i_dcache_sram (
        .Q   ( sramd_rdata      ),
        .CLK ( clk_i            ),
        .CEN ( ~sramd_req       ),     // low-active chip enable
        .WEN ( sramd_wen_n      ),     // low-active byte write enable
        .A   ( sramd_addr[12:2] ),     // word address (8KB = 2048 words)
        .D   ( sramd_wdata      ),
        .OEN ( 1'b0             )      // low-active output enable, always enabled
    );
`endif
    axi2mem #(
        .AXI_ID_WIDTH   ( ID_WIDTH     ),
        .AXI_ADDR_WIDTH ( 32    ),
        .AXI_DATA_WIDTH ( 32    ),
        .AXI_USER_WIDTH ( 1     )
    ) i_axi2sramd (
        .clk_i  ( clk_i             ),
        .rst_ni ( ndmreset_n        ),
        .slave  ( master[idx_sramd] ),
        .req_o  ( sramd_req         ),
        .we_o   ( sramd_we          ),
        .addr_o ( sramd_addr        ),
        .be_o   ( sramd_be          ), // byte enable
        .data_o ( sramd_wdata       ),
        .data_i ( sramd_rdata       )
    );

//--------------------------- idx_accelerator ---------------------------//

    logic           acc_req;
    logic           acc_we;
    logic [31:0]    acc_addr;
    logic [31:0]    acc_wdata;
    logic [31:0]    acc_rdata;

    // accelerator_sim i_acc (
    //     .clka   (clk_i              ),
    //     .ena    (acc_req           ),
    //     .wea    (acc_we   ),
    //     .addra  (acc_addr[12:2]    ),
    //     .dina   (acc_wdata         ),
    //     .douta  (acc_rdata         ),
    //     .rst_ni (ndmreset_n        )
    // );

    NPU_top #(
        .N(10),
        .K_SIZE(3),
        .DATA_WIDTH(8),
        .AXI_WIDTH(32),
        .ADDR_W(3)
    ) i_npu (
        .clk      (clk_i          ),
        .rst_n      (ndmreset_n    ),
        .req_i      (acc_req        ),
        .wen_i      (acc_we         ),
        .addr_i     (acc_addr     ),
        .wdata_i    (acc_wdata    ),
        .rdata_o    (acc_rdata   )
    );

    axi2mem #(
        .AXI_ID_WIDTH   ( ID_WIDTH     ),
        .AXI_ADDR_WIDTH ( 32    ),
        .AXI_DATA_WIDTH ( 32    ),
        .AXI_USER_WIDTH ( 1     )
    ) i_axi2acc (
        .clk_i  ( clk_i             ),
        .rst_ni ( ndmreset_n        ),
        .slave  ( master[idx_acc]  ),
        .req_o  ( acc_req          ),
        .we_o   ( acc_we           ),
        .addr_o ( acc_addr         ),
        .be_o   (                  ),
        .data_o ( acc_wdata        ),
        .data_i ( acc_rdata        )
    );

    logic [31:0] timer_cnt;
    always @(posedge clk_i or negedge rst_ni)
    begin
        if (!rst_ni)
        begin
            clk_led <= 1'b0;
            timer_cnt <= 32'd0;
        end
        else if (timer_cnt == 32'd99_999_999)
        begin
            clk_led <= ~clk_led;
            timer_cnt <= 32'd0;
        end
        else
        begin
            clk_led <= clk_led;
            timer_cnt <= timer_cnt + 32'd1;
        end
    end

    logic [31:0] timer_cnt_tck;
    always @(posedge tck_i or negedge rst_ni)
    begin
        if (!rst_ni)
        begin
            tck_led <= 1'b0;
            timer_cnt_tck <= 32'd0;
        end
        else if (timer_cnt_tck == 32'd99_999_999)
        begin
            tck_led <= ~tck_led;
            timer_cnt_tck <= 32'd0;
        end
        else
        begin
            tck_led <= tck_led;
            timer_cnt_tck <= timer_cnt_tck + 32'd1;
        end
    end
endmodule
