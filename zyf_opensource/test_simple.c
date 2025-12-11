#include <stdint.h>

#define ACC_BASE_ADDR    0x70000000u
#define DCACHE_BASE_ADDR 0x81000000u
#define FIX_SPACE_1  240
#define FIX_SPACE_2  480
#define FIX_SPACE_3  720

uint8_t get_val_conv(int m_n, int r, int c, volatile uint32_t * const dcache) {
    // 计算偏移地址
    int offset = (42 * c + 3 * r) + (m_n / 4);
    uint32_t data = dcache[offset];
    // 提取对应的字节（从最高字节开始：m_n % 4 == 0 -> bits [31:24]）
    int byte_pos = m_n % 4;
    return (uint8_t)((data >> ((3 - byte_pos) * 8)) & 0xFF);
}

uint8_t get_val_fc(int m_n, volatile uint32_t * const dcache) {
    // 计算偏移地址
    int offset = (m_n / 4);
    uint32_t data = dcache[offset];
    // 提取对应的字节（从最高字节开始：m_n % 4 == 0 -> bits [31:24]）
    int byte_pos = m_n % 4;
    return (uint8_t)((data >> ((3 - byte_pos) * 8)) & 0xFF);
}

uint32_t get_new_input_conv(int m_n, int r, int c, volatile uint32_t * const dcache, uint8_t instr) {
    uint32_t new_input = 0;
    new_input |= (instr << 24); // 将instr放在最高的8位
    for (int i = 0; i < 3; i++) {
        new_input |= (get_val_conv(m_n, r, c + i, dcache) << ((2 - i) * 8));
    }
    return new_input;
}

uint32_t get_new_input_fc(int n, volatile uint32_t * const dcache, uint8_t instr) {
    uint32_t new_input = 0;
    new_input |= (instr << 24); // 将instr放在最高的8位
    for (int i = 0; i < 3; i++) {
        new_input |= (get_val_fc(n * 4 + i, dcache) << ((2 - i) * 8));
    }
    return new_input;
}

void store_conv2_output(volatile uint32_t * const dcache, int num_outputs, uint32_t out) {
    // out 的 [15:8] 位应该存储在 dcache + (num_outputs / 3) 的从高位数第 1 + (num_outputs % 3) 个字节中, 其他字节不变
    int offset = num_outputs / 3;
    volatile uint32_t * fc_input_addr = dcache + offset * 33 + 30;
    uint32_t existing_data = *fc_input_addr;
    int byte_pos = num_outputs % 3;
    // 清除对应字节
    // existing_data &= ~(0xFF << ((2 - byte_pos) * 8));
    // 设置新字节
    existing_data |= ((out & 0xFF) << ((2 - byte_pos) * 8));
    *fc_input_addr = existing_data;
}

void store_fc1_output(volatile uint32_t * dcache, volatile uint32_t * acc0) {
    // 1-4
    *acc0 = 0x04000000;
    dcache += 3;
    *dcache |= (0x00FFFFFF & (*acc0 >> 8));
    ++dcache;      // 指向下一个存储位置
    *dcache |= (0x00FF0000 & (*acc0 << 16));
    // 5-8
    *acc0 = 0x08000000;
    *dcache |= (0x0000FFFF & (*acc0 >> 16));
    ++dcache;
    *dcache |= (0x00FFFF00 & (*acc0 << 8));
    // 9、10
    *acc0 = 0x0c000000;
    *dcache |= (0x000000FF & (*acc0 >> 24));
    ++dcache;
    *dcache |= (0x00FF0000 & *acc0);
}

int main(void) {
    volatile uint32_t * const acc0 = (volatile uint32_t *)ACC_BASE_ADDR;
    volatile uint32_t *       src  = (volatile uint32_t *)DCACHE_BASE_ADDR;
    volatile uint32_t *       t_conv1    = (volatile uint32_t *)(DCACHE_BASE_ADDR + 270*4);
    volatile uint32_t *       t_conv2    = (volatile uint32_t *)(DCACHE_BASE_ADDR + 817*4);
    // volatile uint32_t *       t_fc1      = (volatile uint32_t *)(DCACHE_BASE_ADDR + FIX_SPACE_3*4);
    volatile uint32_t *       t_fc2      = (volatile uint32_t *)(DCACHE_BASE_ADDR + 1313*4);
    int conv1_w = 31; // 加载weight
    int conv1_output_1 = 13;
    int conv1_output_2 = 14;

    // 预加载conv1_weight
    while (conv1_w--) {
        *acc0 = *src;
        ++src;
    }   

    // 加载conv1_input
    while (conv1_output_1--) {
        *acc0 = *src;
        ++src;
        *acc0 = *src;
        ++src;
        while (conv1_output_2--) {
            *acc0 = *src;  // 先读原有的数据
            ++src;
            // 1-4
            *acc0 = 0x04000000; //让npu可读
            *t_conv1 = *acc0;  //读取npu中的数据
            ++t_conv1;      // 指向下一个存储位置
            // 5-8
            *acc0 = 0x08000000;
            *t_conv1 = *acc0;
            ++t_conv1;
            // 9、10
            *acc0 = 0x0c000000;
            *t_conv1 = *acc0;
            ++t_conv1;
        }
    }

    // conv2计算
    // 将 t 指针重置到 conv1_output 位置
    t_conv1   = (volatile uint32_t *)(DCACHE_BASE_ADDR + FIX_SPACE_1*4);
    int conv2_w = 31; // 加载weight
    int COUT2 = 10;
    int conv2_output_1 = 11;
    int conv2_output_2 = 12;
    int conv2_input_1 = 13;
    int conv2_input_2 = 14;
    int out_num = 0;

    // 预加载conv2_weight
    while (conv2_w--) {
        *acc0 = *src;
        ++src;
    }   

    // 几个关键参数：m_n, r, c. 对应的4bytes 地址偏移为 =（42 * c + 3 * r）+ [m_n / 4]
    for (int c = 0; c < conv2_output_1; c++) {
        for (int m_n = 0; m_n < COUT2; m_n++) {
            // 预加载前60个input（一个uint32_t装3个data）
            uint32_t new_input = get_new_input_conv(m_n, 0, c, t_conv1, 0x02);
            *acc0 = new_input;
            new_input = get_new_input_conv(m_n, 1, c, t_conv1, 0x02);
            *acc0 = new_input;
        }
        for (int r = 2; r < conv2_input_2; r++) {
            for (int m_n = 0; m_n < COUT2; m_n++) {
                // 计算new_input
                uint32_t new_input = get_new_input_conv(m_n, r, c, t_conv1, 0x42);
                *acc0 = new_input;
            }
            // 10个计算结果，计算出来将存储到 t_conv2 中
            *acc0 = 0x0C000000;
            // t_conv2 是原有的数据空间，其中高为byte已经被赋予了instr
            store_conv2_output(t_conv2, out_num, *acc0);
            out_num++;
        }
    }
    src += 546;

    // fc1计算
    t_conv2   = (volatile uint32_t *)(DCACHE_BASE_ADDR + FIX_SPACE_2*4);
    int fc1_group = 15;
    *acc0 = *src;
    ++src;
    // 这里直接加载dcache里的data就可以，因为input已经在conv2中被组装了
    for (int g = 0; g < fc1_group; g++) {
        int fc1_w = 33; // 加载weight
        while (fc1_w--) {
            *acc0 = *src;
            ++src;
        }
    }

    store_fc1_output(t_fc2, acc0);
    
    // fc2计算
    int fc2_group = 2;
    *acc0 = *src;
    ++src;
    for (int g = 0; g < fc2_group; g++) {
        int fc2_w = 6; // 加载weight
        while (fc2_w--) {
            *acc0 = *src;
            ++src;
        }
    }

    *acc0 = 0x0C000000;

    // 从结果的第[7:0]位读出最后的结果

    uint8_t final_result = (uint8_t)(*acc0 & 0xFF);
    *src = (uint32_t)final_result;

    return 0;
}

