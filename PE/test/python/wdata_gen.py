import torch
import torch.nn as nn
import torch.nn.functional as F
import numpy as np

def write_instr(f):
    instr = str(layer_select_en)+str(reuse)+str(relu_en)+str(broadcast_en)+format(write_back_mode, '02b')+format(load_mode, '02b')
    wdata = instr+load_data_1+load_data_2+load_data_3
    f.write(f"{wdata}\n")

def load_hex_weights(file_path):
    with open(file_path, 'r') as f:
        data = f.read().splitlines()
    weights = []
    for line in data:
        for val in line.split():
            int_val = int(val, 16)
            bin_str = format(int_val, '08b')
            weights.append(bin_str)
    return weights

def load_sample_input(file_path):
    with open(file_path, "r") as f:
        data = f.read().split()
    data = np.array(list(map(int, data)), dtype=np.int32)
    data = data.reshape(5, 1, 16, 15)
    return data

def load_conv2_input(file_path):
    with open(file_path, 'r') as f:
        data = f.read().splitlines()
    out_npu = []
    for i in range(546):
        data_1 = data[i][0:8]
        data_2 = data[i][8:16]
        data_3 = data[i][16:24]
        data_4 = data[i][24:32]
        out_npu.append(int(data_1, 2))
        out_npu.append(int(data_2, 2))
        if (i % 3 != 2):
            out_npu.append(int(data_3, 2))
            out_npu.append(int(data_4, 2))
    out_npu = np.array(out_npu)
    out_npu = out_npu.reshape(1, 13, 14, 10)
    # 转置
    out_npu = out_npu.transpose(0, 3, 2, 1)
    out_npu = torch.from_numpy(out_npu)
    return out_npu

def load_fc1_input(file_path):
    with open(file_path, 'r') as f:
        data = f.read().splitlines()
    out_npu = []
    for i in range(546, 942):
        data_3 = data[i][16:24]
        if (i % 3 == 2):
            out_npu.append(int(data_3, 2))
    out_npu = np.array(out_npu)
    out_npu = out_npu.reshape(1, 11, 12, 1)
    # 转置
    out_npu = out_npu.transpose(0, 3, 2, 1)
    out_npu = torch.from_numpy(out_npu)
    out_npu = out_npu.flatten(1)
    out_npu = torch.nn.functional.pad(out_npu, (0, 3), "constant", 0)
    return out_npu

def load_fc2_input(file_path):
    with open(file_path, 'r') as f:
        data = f.read().splitlines()
    out_npu = []
    for i in range(942, 945):
        data_1 = data[i][0:8]
        data_2 = data[i][8:16]
        data_3 = data[i][16:24]
        data_4 = data[i][24:32]
        out_npu.append(int(data_1, 2))
        out_npu.append(int(data_2, 2))
        if (i % 3 != 2):
            out_npu.append(int(data_3, 2))
            out_npu.append(int(data_4, 2))
    out_npu = np.array(out_npu)
    out_npu = torch.from_numpy(out_npu)
    out_npu = torch.nn.functional.pad(out_npu, (0, 8), "constant", 0)
    return out_npu

def waiting(f, cycles):    
    global layer_select_en, addr_i, reuse, write_back_mode, relu_en, broadcast_en, load_mode, load_data_1, load_data_2, load_data_3
    layer_select_en = 0
    addr_i = 0
    reuse = 0
    write_back_mode = 0
    relu_en = 1
    broadcast_en = 1
    load_mode = 0
    load_data_1 = format(0, '08b')
    load_data_2 = format(0, '08b')
    load_data_3 = format(0, '08b')
    for _ in range(cycles):
        write_instr(f)

def write_back(f):
    global layer_select_en, addr_i, reuse, write_back_mode, relu_en, broadcast_en, load_mode, load_data_1, load_data_2, load_data_3
    layer_select_en = 0
    addr_i = 0
    reuse = 0
    relu_en = 1
    broadcast_en = 1
    load_mode = 0
    for i in range(3):
        write_back_mode = i + 1
        write_instr(f)

def switch_layer(f, layer):
    global layer_select_en, addr_i, reuse, write_back_mode, relu_en, broadcast_en, load_mode, load_data_1, load_data_2, load_data_3
    layer_select_en = 1
    addr_i = 0
    reuse = 0
    line_count = 0
    if layer == 'conv1':
        reuse = 1
        relu_en = 1
        broadcast_en = 0
        line_count = 14
    elif layer == 'conv2':
        reuse = 1
        relu_en = 0
        broadcast_en = 0
        line_count = 12
    elif layer == 'fc1':
        reuse = 0
        relu_en = 1
        broadcast_en = 0
        line_count = 1
    elif layer == 'fc2':
        reuse = 0
        relu_en = 1
        broadcast_en = 1
        line_count = 1
    write_back_mode = line_count // 4
    load_mode = line_count % 4
    load_data_1 = format(0, '08b')
    load_data_2 = format(0, '08b')
    load_data_3 = format(0, '08b')
    write_instr(f)

def conv1_load_A(f):
    global layer_select_en, addr_i, reuse, write_back_mode, relu_en, broadcast_en, load_mode, load_data_1, load_data_2, load_data_3
    
    conv1_weight = load_hex_weights('handout_new/data/conv1_weight.txt')

    layer_select_en = 0
    addr_i = 0
    reuse = 0
    write_back_mode = 0
    relu_en = 0
    broadcast_en = 0
    load_mode = 1
    for i in range(30):
        load_data_1 = conv1_weight[i*3]
        load_data_2 = conv1_weight[i*3 + 1]
        load_data_3 = conv1_weight[i*3 + 2]
        write_instr(f)

def conv1_load_C(f):
    global layer_select_en, addr_i, reuse, write_back_mode, relu_en, broadcast_en, load_mode, load_data_1, load_data_2, load_data_3

    sample_input = load_sample_input('handout_new/data/sample_input.txt')
    sample_input = sample_input[0, 0]  # shape: (16, 15)

    for col in range(1, 14):
        for row in range(1, 15):
            layer_select_en = 0
            addr_i = 0
            write_back_mode = 0
            relu_en = 0
            broadcast_en = 0
            load_mode = 3
            cycles = 1
            if row == 1:
                reuse = 0
                for i in [row-1, row, row+1]:
                    load_data_1 = format(sample_input[i, col-1], '08b')
                    load_data_2 = format(sample_input[i, col], '08b')
                    load_data_3 = format(sample_input[i, col+1], '08b')
                    write_instr(f)
            else:
                reuse = 1
                load_data_1 = format(sample_input[row+1, col-1], '08b')
                load_data_2 = format(sample_input[row+1, col], '08b')
                load_data_3 = format(sample_input[row+1, col+1], '08b')
                write_instr(f)
            waiting(f, cycles)
            write_back(f)

def conv2_load_A(f):
    global layer_select_en, addr_i, reuse, write_back_mode, relu_en, broadcast_en, load_mode, load_data_1, load_data_2, load_data_3
    
    conv2_weight = load_hex_weights('handout_new/data/conv2_weight.txt')

    layer_select_en = 0
    addr_i = 0
    reuse = 0
    write_back_mode = 0
    relu_en = 0
    broadcast_en = 0
    load_mode = 1
    for i in range(30):
        load_data_1 = conv2_weight[i*3]
        load_data_2 = conv2_weight[i*3 + 1]
        load_data_3 = conv2_weight[i*3 + 2]
        write_instr(f)

def conv2_load_B(f):
    global layer_select_en, addr_i, reuse, write_back_mode, relu_en, broadcast_en, load_mode, load_data_1, load_data_2, load_data_3

    conv2_input = load_conv2_input('rdata_output.txt')
    conv2_input = conv2_input[0]  # shape: (10, 14, 13)

    for col in range(1, 12):
        for row in range(1, 13):
            layer_select_en = 0
            addr_i = 0
            write_back_mode = 0
            relu_en = 0
            broadcast_en = 0
            load_mode = 2
            if row == 1:
                reuse = 0
                cycles = 1
                for i in [row-1, row, row+1]:
                    for j in range(10):
                        load_data_1 = format(conv2_input[j, i, col-1], '08b')
                        load_data_2 = format(conv2_input[j, i, col], '08b')
                        load_data_3 = format(conv2_input[j, i, col+1], '08b')
                        write_instr(f)
            else:
                reuse = 1
                cycles = 1
                for j in range(10):
                    load_data_1 = format(conv2_input[j, row+1, col-1], '08b')
                    load_data_2 = format(conv2_input[j, row+1, col], '08b')
                    load_data_3 = format(conv2_input[j, row+1, col+1], '08b')
                    write_instr(f)
            waiting(f, cycles)
            write_back(f)

def fc1_load_A_C(f):
    global layer_select_en, addr_i, reuse, write_back_mode, relu_en, broadcast_en, load_mode, load_data_1, load_data_2, load_data_3
    
    fc1_weight = load_hex_weights('handout_new/data/fc1_weight.txt')
    fc1_weight = np.array(fc1_weight)
    fc1_weight = fc1_weight.reshape(10, 132)  # Reshaping 9x10 to 3x3x10x1
    pad_values = np.full((10, 3), '00000000', dtype=object)
    fc1_weight = np.hstack((fc1_weight, pad_values))
    fc1_input = load_fc1_input('rdata_output.txt') # shape: (1, 135)

    layer_select_en = 0
    addr_i = 0
    reuse = 0
    write_back_mode = 0
    relu_en = 1
    broadcast_en = 1
    for i in range(15):
        load_mode = 1
        for j in range(10):
            for k in range(3):
                load_data_1 = fc1_weight[j, i*9 + k*3]
                load_data_2 = fc1_weight[j, i*9 + k*3 + 1]
                load_data_3 = fc1_weight[j, i*9 + k*3 + 2]
                write_instr(f)
        load_mode = 3
        for k in range(3):
            load_data_1 = format(fc1_input[0, i*9 + k*3], '08b')
            load_data_2 = format(fc1_input[0, i*9 + k*3 + 1], '08b')
            load_data_3 = format(fc1_input[0, i*9 + k*3 + 2], '08b')
            write_instr(f)
        waiting(f, 1)
    write_back(f)

def fc2_load_A_C(f):
    global layer_select_en, addr_i, reuse, write_back_mode, relu_en, broadcast_en, load_mode, load_data_1, load_data_2, load_data_3
    
    fc2_weight = load_hex_weights('handout_new/data/fc2_weight.txt')
    fc2_weight = np.array(fc2_weight)
    pad_values = np.full(8, '00000000', dtype=object)
    fc2_weight = np.hstack((fc2_weight, pad_values))
    fc2_input = load_fc2_input('rdata_output.txt') # shape: (90)

    layer_select_en = 0
    addr_i = 0
    reuse = 0
    write_back_mode = 0
    relu_en = 1
    broadcast_en = 1
    for j in range(2):
        load_mode = 1
        for i in range(3):
            load_data_1 = fc2_weight[j*9 + i*3]
            load_data_2 = fc2_weight[j*9 + i*3 + 1]
            load_data_3 = fc2_weight[j*9 + i*3 + 2]
            write_instr(f)
        load_mode = 3
        for i in range(3):
            load_data_1 = format(fc2_input[j*9 + i*3], '08b')
            load_data_2 = format(fc2_input[j*9 + i*3 + 1], '08b')
            load_data_3 = format(fc2_input[j*9 + i*3 + 2], '08b')
            write_instr(f)
        waiting(f, 1)
    write_back(f)

# initialize signals
rst_n = 0
req_i = 1
layer_select_en = 0             # 4 bits
addr_i = 0            # 3 bits
reuse = 0
write_back_mode = 0   # 2 bits
relu_en = 0
broadcast_en = 0
load_mode = 0         # 2 bits
load_data_1 = 0       # 8 bits
load_data_2 = 0       # 8 bits
load_data_3 = 0       # 8 bits

file_path = 'wdata_input.txt'
with open(file_path, 'w') as f:

    # conv1
    switch_layer(f, 'conv1') # switch to conv1
    conv1_load_A(f) # LOAD_A for conv1
    conv1_load_C(f) # LOAD_C for conv1

    # conv2
    switch_layer(f, 'conv2') # switch to conv2
    conv2_load_A(f) # LOAD_A for conv2
    conv2_load_B(f) # LOAD_B for conv2

    # fc1
    switch_layer(f, 'fc1') # switch to fc1
    fc1_load_A_C(f) # LOAD_A and LOAD_C for fc1

    # fc2
    switch_layer(f, 'fc2') # switch to fc2
    fc2_load_A_C(f) # LOAD_A and LOAD_C for fc2