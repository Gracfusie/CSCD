import torch
import torch.nn as nn
import torch.nn.functional as F
import numpy as np

def write_instr(f):
    instr = str(wen_i)+str(reuse)+format(write_back_mode, '02b')+str(relu_en)+str(broadcast_en)+format(load_mode, '02b')
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

def load_A(f):
    global wen_i, addr_i, reuse, write_back_mode, relu_en, broadcast_en, load_mode, load_data_1, load_data_2, load_data_3
    
    conv1_weight = load_hex_weights('handout_new/data/conv1_weight.txt')

    wen_i = 1
    addr_i = 0
    reuse = 0
    write_back_mode = 3
    relu_en = 1
    broadcast_en = 1
    load_mode = 1
    for i in range(30):
        load_data_1 = conv1_weight[i*3]
        load_data_2 = conv1_weight[i*3 + 1]
        load_data_3 = conv1_weight[i*3 + 2]
        write_instr(f)

def waiting(f, cycles):    
    global wen_i, addr_i, reuse, write_back_mode, relu_en, broadcast_en, load_mode, load_data_1, load_data_2, load_data_3
    wen_i = 0
    addr_i = 0
    reuse = 0
    write_back_mode = 3
    relu_en = 1
    broadcast_en = 1
    load_mode = 0
    load_data_1 = format(0, '08b')
    load_data_2 = format(0, '08b')
    load_data_3 = format(0, '08b')
    for _ in range(cycles):
        write_instr(f)

def write_back(f):
    global wen_i, addr_i, reuse, write_back_mode, relu_en, broadcast_en, load_mode, load_data_1, load_data_2, load_data_3
    wen_i = 0
    addr_i = 0
    reuse = 0
    relu_en = 1
    broadcast_en = 1
    load_mode = 0
    for i in range(3):
        write_back_mode = i
        write_instr(f)

def load_C(f):
    global wen_i, addr_i, reuse, write_back_mode, relu_en, broadcast_en, load_mode, load_data_1, load_data_2, load_data_3

    sample_input = load_sample_input('handout_new/data/sample_input.txt')
    sample_input = sample_input[0, 0]  # shape: (16, 15)

    for col in range(1, 14):
        for row in range(1, 15):
            wen_i = 1
            addr_i = 0
            write_back_mode = 3
            relu_en = 1
            broadcast_en = 1
            load_mode = 3
            if row == 1:
                reuse = 0
                cycles = 10
                for i in [row-1, row, row+1]:
                    load_data_1 = format(sample_input[i, col-1], '08b')
                    load_data_2 = format(sample_input[i, col], '08b')
                    load_data_3 = format(sample_input[i, col+1], '08b')
                    write_instr(f)
            else:
                reuse = 1
                cycles = 11
                load_data_1 = format(sample_input[row+1, col-1], '08b')
                load_data_2 = format(sample_input[row+1, col], '08b')
                load_data_3 = format(sample_input[row+1, col+1], '08b')
                write_instr(f)
            waiting(f, cycles)
            write_back(f)


# initialize signals
rst_n = 0
req_i = 1
wen_i = 0             # 4 bits
addr_i = 0            # 3 bits
reuse = 0
write_back_mode = 3   # 2 bits
relu_en = 0
broadcast_en = 0
load_mode = 0         # 2 bits
load_data_1 = 0       # 8 bits
load_data_2 = 0       # 8 bits
load_data_3 = 0       # 8 bits

file_path = 'wdata_input.txt'
with open(file_path, 'w') as f:
    # LOAD_A
    load_A(f)
    # LOAD_C
    load_C(f)