/* 文件名: link.ld (JTAG 直加载版) */
OUTPUT_ARCH(riscv)
ENTRY(_start)

MEMORY
{
  /* SRAM0: 代码和普通只读常量 (如字符串) */
  SRAM0 (rx)  : ORIGIN = 0x80000000, LENGTH = 8K
  /* SRAM1: 权重数据、全局变量、堆栈 */
  SRAM1 (rwx) : ORIGIN = 0x81000000, LENGTH = 8K
}

SECTIONS
{
  /* 1. 代码段和普通只读数据：显式从 SRAM0 起始地址开始 */
  . = ORIGIN(SRAM0);
  .text : {
    . = ALIGN(4);
    KEEP(*(.init))       /* 如果有启动代码放 .init，确保不会被链接器丢掉 */
    *(.text*)
    *(.rodata*)          /* 普通 const 字符串等 */
    . = ALIGN(4);
  } > SRAM0

  /* 2. SRAM1 上从起始地址开始依次放 weights / data / bss */
  . = ORIGIN(SRAM1);

  /* 2.1 神经网络权重段 */
  .weights : {
    . = ALIGN(4);
    *(.weights)          /* 你在 C 里用 __attribute__((section(".weights"))) 标的变量 */
    . = ALIGN(4);
  } > SRAM1

  /* 2.2 普通已初始化数据段 */
  .data : {
    . = ALIGN(4);
    *(.data*)
    . = ALIGN(4);
  } > SRAM1

  /* 2.3 BSS 段 (未初始化或为0的数据)，由 startup 代码清零 */
  .bss : {
    . = ALIGN(4);
    _sbss = .;           /* BSS 清零开始地址 */
    *(.bss*)
    *(COMMON*)
    . = ALIGN(4);
    _ebss = .;           /* BSS 清零结束地址 */
  } > SRAM1

  /* 堆栈顶端：SRAM1 末尾 */
  _stack_start = ORIGIN(SRAM1) + LENGTH(SRAM1);
}
