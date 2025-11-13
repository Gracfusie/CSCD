/* Register Allocation */
/* a0: start address */
/* a1: target address */
/* a2: the boundary of first loop i1 */
/* a3: the boundary of second loop i2 */
/* t0: temporary register, recurrent counter */
/* t1: temporary register */
/* t2-t5: four target address */

.global _boot
.text

.set DCACHE_BASE, 0x81000000
.set NPU_BASE,    0x70000000
.set LWEIGHT_N,   30

_boot:

    li  t0, 0               /* t0 = i */
    li  t4, LWEIGHT_N       /* t4 = loop bound */
    li  t5, DCACHE_BASE     /* t5 = base address */
    li  t6, NPU_BASE        /* t6 = npu base */

loop1_start:
    bge  t0, t4, loop1_end

    slli t3, t0, 2          /* offset = i * 4 (word size) */
    add  t1, t5, t3         /* t1 = DCACHE_BASE + offset */

    lw   t2, 0(t1)          /* weight, dcache->reg */
    sw   t2, 0(t6)          /* weight, reg->npu_wdata */

    addi t0, t0, 1
    j    loop1_start
loop1_end:

    

