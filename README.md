# CSCD
CNN System Chip Design (Part of RTL and testbench)

Feishu link: https://bcncr0uo1h2n.feishu.cn/wiki/Fgt2wYKJciuy69ksGFvc6SXSnoa?from=from_copylink

## Build Instructions

### Simulation
在主目录下运行。使用`rtl`文件夹下的`filelist.f`。`TOP`后跟着的是源文件列表中的顶层模块（目前使用的`cv32e40p_xilinx_tb`在`rtl/cv32e40p/fpga/tb/cv32e40p_xilinx_tb.sv`中）

仿真使用Synopsis VCS，运行结果在`sim/build`。
```
make vcs TOP=cv32e40p_xilinx_tb
```
仿真并打开波形，打开的波形就是VCS生成的fsdb文件。Verdi也需要读取源文件列表，以提供上下文索引。
```
make verdi TOP=cv32e40p_xilinx_tb
```

## Structure of `cv32e40p`

`rtl` 应该是 CPU 核，包含总线的顶层在 `fpga` 里面。lab1所给的文件夹，还有`wrapper`和`macro`在外面，没搬到这里来。
### 主要子目录与功能（按常见分类）
#### 1) `src/cv32e40p/rtl`
- 功能：CPU 核心（CV32E40P）的寄存器传输级实现。包含核心子模块（IF/ID/EX/MEM/WB）、ALU、控制器、加载存储单元、FPU wrapper/子模块、寄存器堆、队列/ FIFO 等。
- 典型文件与作用：
    - cv32e40p_core.sv：CPU 核心顶层实现（组合子模块，pipeline 管理）。
    - cv32e40p_top.sv：顶层封装（可能包含外设/接口的连接）。
    - cv32e40p_if_stage.sv、cv32e40p_id_stage.sv、cv32e40p_ex_stage.sv：IF/ID/EX pipeline stage。
    - cv32e40p_decoder.sv / cv32e40p_compressed_decoder.sv：指令解码器（含压缩指令）。
    - cv32e40p_alu.sv、cv32e40p_mult.sv、cv32e40p_alu_div.sv：算术与乘除单元。
    - cv32e40p_load_store_unit.sv、cv32e40p_aligner.sv：内存对齐与加载/存储单元。
    - cv32e40p_register_file_ff.sv：寄存器堆实现（含寄存器前推/冲突处理）。
include/*.sv：包（package）与宏定义（如 cv32e40p_pkg.sv, cv32e40p_fpu_pkg.sv），全局参数/类型定义。
- 提示：该目录是阅读/修改核心逻辑的主要位置。想理解 pipeline 流水线或添加指令扩展，从这里入手。
#### 2) `src/cv32e40p/bhv`
- 功能：行为级测试/跟踪、仿真辅助模块、RVFI 接口追踪、trace 与仿真监控脚本（SystemVerilog behavioral testbench 片段）。
- 典型文件：
    - cv32e40p_tb_wrapper.sv：测试平台封装（testbench wrapper）。
    - cv32e40p_tracer.sv、insn_trace.sv、pipe_freeze_trace.sv：指令/流水线跟踪（生成 trace 文件、帮助调试）。
    - cv32e40p_rvfi.sv / cv32e40p_rvfi_trace.sv：RVFI（RISC-V Verification Interface）输出与记录，用于 ISA 级验证与对接验证框架。
- 用途：调试和指令行为验证。查看仿真日志、RVFI 输出、指令追踪都在这里。

#### 3) `src/cv32e40p/fpga`(助教后来加的)
- 功能：面向 FPGA 的适配实现（替换或封装某些 IP 以便在 FPGA 上仿真/跑板），包含 FPGA-specific SRAM model、加速器仿真或 Xilinx 特定 glue code。
- 典型文件：
    - fpga/rtl/src/bootrom.sv, bootram.sv, sram_ff.sv：FPGA 友好的内存/boot ROM 模块。
    - fpga/rtl/src/cv32e40p_xilinx.sv：为 Xilinx FPGA 适配的 wrapper/时钟/复位拓展。
    - fpga/tb/*.sv：FPGA Testbench（例如 cv32e40p_xilinx_tb.sv）。
- 提示：在准备下载到板子或在 FPGA 上跑时检查此目录的实现。

#### 4) `src/cv32e40p/rtl/vendor`（第三方/复用模块）
- 功能：包含来自 PULP、fpnew、OpenE906 等第三方库或子模块，例如通用流水线帮助模块、FPU、FIFO、stream 接口等。
- 典型模块：
    - pulp_platform_common_cells：各种通用硬件单元（fifo、stream、lfsr、sync 等）。
    - pulp_platform_fpnew / opene906：浮点单元（FPU）实现，div/sqrt、FMA 等。
- 用途：这些是可复用组件，CPU 的浮点/高级功能通常通过这些模块提供。