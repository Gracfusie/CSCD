# 状态机总结

![流程图](./image/dataflow.png)

1. `pe_reg_reset`：9次一更新。
2. `pe_mode_sel`：基本都是全选，至少在第一层convolution中如此。
3. `pe_mux_a_sel`：涉及到如何算卷积的方式，以及如何复用数据。
   1. 设计指针：byte_ptr，当前需要取的数据的相对位置（0-8循环）。block_head当前正在计算的数据块的头位置（0->3->6->0-> ...循环。真正需要存数据块中取的相对位置为(block_head+byte_ptr) 溢出自动截取，最大$\leq 8$in_ptr，当前需要存的数据块的相对位置（0-2循环）。
4. `pe_en`：控制PE单元的启动与否。
5. `pe_mux_b_sel`：与`pe_mux_a_sel`类似，但需要决定是否将input广播。