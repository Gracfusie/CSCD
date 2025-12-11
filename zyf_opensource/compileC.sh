#!/bin/bash

# =========================
# 配置
# =========================
SOURCE_NAME=test_simple          # C 源文件名（不带 .c）
OUTPUT_DIR=output

RISCV_TOOLCHAIN_ROOT=/home/almalinux/opt/riscv
RISCV_BIN_DIR=${RISCV_TOOLCHAIN_ROOT}/bin

# RISC-V 32 位工具链前缀
GCC_PREFIX=riscv32-unknown-linux-gnu

# 架构：RV32IM + ILP32
ARCH_FLAGS="-march=rv32im -mabi=ilp32"

# 本地头文件目录（自己提供 stdint.h 等）
LOCAL_INCLUDE_DIR=$(pwd)/rv32-headers

# 链接脚本（使用你刚才的 link.ld）
LINKER_SCRIPT=link.ld

export PATH=${RISCV_BIN_DIR}:$PATH
export RISCV=${RISCV_TOOLCHAIN_ROOT}

# =========================
# 编译 / 链接参数
# 关键：打开 -O2 优化
# =========================
CFLAGS="${ARCH_FLAGS} -O2 -ffreestanding -nostdlib -nostartfiles -fno-builtin -I${LOCAL_INCLUDE_DIR}"
LDFLAGS="${ARCH_FLAGS} -nostdlib -nostartfiles"

mkdir -p ${OUTPUT_DIR}
echo "Build outputs will be placed in '${OUTPUT_DIR}/' directory."

# =========================
# 输出文件名
# =========================
CRT0_OBJ=${OUTPUT_DIR}/crt0.o
SOURCE_OBJ=${OUTPUT_DIR}/${SOURCE_NAME}.o
ELF_FILE=${OUTPUT_DIR}/${SOURCE_NAME}.elf
MAP_FILE=${OUTPUT_DIR}/${SOURCE_NAME}.map

INSTR_RAW=${OUTPUT_DIR}/${SOURCE_NAME}_instr_raw.hex
DATA_RAW=${OUTPUT_DIR}/${SOURCE_NAME}_data_raw.hex
INSTR_FINAL=${OUTPUT_DIR}/instr.hex
DATA_FINAL=${OUTPUT_DIR}/data.hex

# 人类可读的指令反汇编
INSTR_TEXT=${OUTPUT_DIR}/${SOURCE_NAME}_instr.txt

DATA_SECTION_PRESENT=0

# =========================
# Step 1: 汇编启动文件 crt0.S
# =========================
echo "Step 1: Assembling crt0.S to ${CRT0_OBJ}"
${GCC_PREFIX}-gcc -c ${CFLAGS} -o ${CRT0_OBJ} crt0.S
if [ $? -ne 0 ]; then echo "Assembly failed!"; exit 1; fi

# =========================
# Step 2: 编译 C 源文件
# =========================
echo "Step 2: Compiling ${SOURCE_NAME}.c to ${SOURCE_OBJ}"
${GCC_PREFIX}-gcc -c ${CFLAGS} -o ${SOURCE_OBJ} ${SOURCE_NAME}.c
if [ $? -ne 0 ]; then echo "Compilation failed!"; exit 1; fi

# =========================
# Step 3: 链接生成 ELF
# =========================
echo "Step 3: Linking object files to ${ELF_FILE}"
${GCC_PREFIX}-gcc ${LDFLAGS} -T ${LINKER_SCRIPT} \
    -o ${ELF_FILE} ${CRT0_OBJ} ${SOURCE_OBJ} -Wl,-Map=${MAP_FILE}
if [ $? -ne 0 ]; then echo "Linking failed!"; exit 1; fi

# =========================
# Step 4a: 提取指令 SRAM (SRAM0, 0x8000_0000)
# =========================
echo "Step 4a: Extracting Instruction SRAM (SRAM0) to ${INSTR_RAW}"
${GCC_PREFIX}-objcopy -O verilog \
    -j .text -j .rodata \
    --change-addresses -0x80000000 \
    ${ELF_FILE} ${INSTR_RAW}
if [ $? -ne 0 ]; then echo "Instr extraction failed!"; exit 1; fi

# =========================
# Step 4b: 提取数据 SRAM (SRAM1, 0x8100_0000)
# 只取 .weights 和 .data 段
# =========================
echo "Step 4b: Extracting Data SRAM (SRAM1) to ${DATA_RAW}"
${GCC_PREFIX}-objcopy -O verilog \
    -j .weights -j .data \
    --change-addresses -0x81000000 \
    ${ELF_FILE} ${DATA_RAW}
DATA_OBJCOPY_RET=$?

if [ ${DATA_OBJCOPY_RET} -ne 0 ]; then
    echo "Warning: Data/weights extraction failed (no .weights/.data?). Skipping data hex generation."
    DATA_SECTION_PRESENT=0
else
    if [ ! -s ${DATA_RAW} ]; then
        echo "No .weights/.data content found in ELF, skipping data hex generation."
        DATA_SECTION_PRESENT=0
    else
        DATA_SECTION_PRESENT=1
    fi
fi

# =========================
# Step 5: Verilog hex -> 仿真用 32bit 一行一字
# =========================
echo "Step 5: Formatting hex files"
python3 convert_hex.py ${INSTR_RAW} ${INSTR_FINAL}
if [ $? -ne 0 ]; then echo "Instr hex formatting failed!"; exit 1; fi

if [ ${DATA_SECTION_PRESENT} -eq 1 ]; then
    python3 convert_hex.py ${DATA_RAW} ${DATA_FINAL}
    if [ $? -ne 0 ]; then
        echo "Warning: Data hex formatting failed, but continuing (no data/weights used?)."
    fi
else
    echo "Skipping data.hex generation (no data/weights section)."
fi

# =========================
# Step 6: 生成可读指令反汇编
# =========================
echo "Step 6: Generating human-readable instruction text to ${INSTR_TEXT}"
${GCC_PREFIX}-objdump -d -M numeric,no-aliases ${ELF_FILE} > ${INSTR_TEXT}
if [ $? -ne 0 ]; then echo "Disassembly failed!"; exit 1; fi

# =========================
# Done
# =========================
echo ""
echo "--- Success! ---"
echo "Instruction Hex for simulation : ${INSTR_FINAL}"
if [ ${DATA_SECTION_PRESENT} -eq 1 ]; then
    echo "Data/Weight Hex for simulation : ${DATA_FINAL}"
else
    echo "Data/Weight Hex for simulation : (not generated, no .weights/.data section)"
fi
echo "Human-readable instruction text: ${INSTR_TEXT}"
echo "All build artifacts are located in the '${OUTPUT_DIR}/' directory."
