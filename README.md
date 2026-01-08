# CSCD
CNN System Chip Design (Part of RTL and testbench)

Feishu link: https://bcncr0uo1h2n.feishu.cn/wiki/Fgt2wYKJciuy69ksGFvc6SXSnoa?from=from_copylink

## How to Simulation 如何仿真
在主目录下运行。使用`rtl`文件夹下的`filelist.f`。`TOP`后跟着的是源文件列表中的顶层模块（目前使用的`cv32e40p_xilinx_tb`在`rtl/cv32e40p/fpga/tb/cv32e40p_xilinx_tb.sv`中），可更改总线的模块在`rtl/cv32e40p/fpga/rtl/src/cv32e40p_xilinx.sv`

仿真使用Synopsis VCS，运行结果在`sim/build`。
```
make vcs
```
仿真并打开波形，打开的波形就是VCS生成的fsdb文件。Verdi也需要读取源文件列表，以提供上下文索引。可以维护`sim/signal.rc`的波形
```
make verdi
```
## Project Structure 项目结构
- PE 文件夹是 NPU 的设计代码，rtl 文件夹下面是课程平台提供的设计框架。
    - cv32e40p 是课程平台提供的 CPU 和 AXI 总线以及用于仿真的顶层，我们的设计基于此开发。
    - RA1SHD_2048x32M8 是课程平台提供的 8KB SRAM。
- sim 文件夹是仿真脚本，仿真的生成在 build 子文件夹。
- pianlai_opensource 文件夹是CNN推理过程的底层代码表述，基于`riscv-gnu-toolchain`编译成机器码。

## Design Profile

| ![tapeout](./image/tapeout.png) | ![NPU架构](./image/npu_arch.svg) |
|:------------------:|:------------------:|
|       设计版图        |       NPU结构        |