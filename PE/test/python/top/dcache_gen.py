import torch
import torch.nn as nn
import torch.nn.functional as F
import numpy as np

# load the correct output
q_sample_input = torch.load('../output_py.pt')['input']
output_conv1 = torch.load('../output_py.pt')['output_conv1']
output_conv2_im = torch.load('../output_py.pt')['output_conv2_im']
output_conv2 = torch.load('../output_py.pt')['output_conv2']
output_fc1 = torch.load('../output_py.pt')['output_fc1']
output_fc2 = torch.load('../output_py.pt')['output_fc2']

def write_instr(f):
    instr = str(layer_select_en)+str(reuse)+str(relu_en)+str(broadcast_en)+format(write_back_mode, '02b')+format(load_mode, '02b')
    wdata = ''
    for i in [instr, load_data_1, load_data_2, load_data_3]:
        wdata += format(int(i, 2), '02x')
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
    
    conv1_weight = load_hex_weights('../handout_new/data/conv1_weight.txt')

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

    sample_input = q_sample_input[0, 0]  # shape: (16, 15)

    for col in range(1, 14):
        for row in range(1, 15):
            layer_select_en = 0
            addr_i = 0
            write_back_mode = 0
            relu_en = 0
            broadcast_en = 0
            load_mode = 3
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

def conv2_load_A(f):
    global layer_select_en, addr_i, reuse, write_back_mode, relu_en, broadcast_en, load_mode, load_data_1, load_data_2, load_data_3
    
    conv2_weight = load_hex_weights('../handout_new/data/conv2_weight.txt')

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

def conv2_load_B(f, ref=False):
    if (ref):
        for w in range(13):
            for h in range(14):
                for c in range(3):
                    load_data_1 = output_conv1[0, 4*c, h, w]
                    load_data_2 = output_conv1[0, 4*c+1, h, w]
                    if c < 2:
                        load_data_3 = output_conv1[0, 4*c+2, h, w]
                        load_data_4 = output_conv1[0, 4*c+3, h, w]
                    else:
                        load_data_3 = 0
                        load_data_4 = 0
                    wdata = ''
                    for i in [load_data_1, load_data_2, load_data_3, load_data_4]:
                        wdata += format(i, '02x')
                    f.write(f"{wdata}\n")
    else:
        for i in range(546):
            f.write('00000000\n')

def fc1_load_A_C(f, ref=False):
    global layer_select_en, addr_i, reuse, write_back_mode, relu_en, broadcast_en, load_mode, load_data_1, load_data_2, load_data_3
    
    fc1_weight = load_hex_weights('../handout_new/data/fc1_weight.txt')
    fc1_weight = np.array(fc1_weight)
    # fc1_weight = fc1_weight.reshape(10, 132)
    fc1_weight = fc1_weight.reshape(10, 12, 11)
    fc1_weight = fc1_weight.transpose(0, 2, 1)
    fc1_weight = fc1_weight.reshape(10, 132)
    pad_values = np.full((10, 3), '00000000', dtype=object)
    fc1_weight = np.hstack((fc1_weight, pad_values))
    fc1_input = torch.zeros((1, 135), dtype=torch.uint8)
    if (ref):
        for w in range(11):
            for h in range(12):
                fc1_input[0, w*12 + h] = output_conv2[0, 0, h, w]

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

def fc2_load_A_C(f, ref=False):
    global layer_select_en, addr_i, reuse, write_back_mode, relu_en, broadcast_en, load_mode, load_data_1, load_data_2, load_data_3
    
    fc2_weight = load_hex_weights('../handout_new/data/fc2_weight.txt')
    fc2_weight = np.array(fc2_weight)
    pad_values = np.full(8, '00000000', dtype=object)
    fc2_weight = np.hstack((fc2_weight, pad_values))
    fc2_input = torch.zeros((18,), dtype=torch.uint8)
    if (ref):
        for i in range(10):
            fc2_input[i] = output_fc1[0, i]

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

def final_result(f, ref=False):
    if (ref):
        f.write('000000' + format(int(output_fc2[0]), '02x'))
    else:
        f.write('00000000')

def dcache_gen(file_path, ref):

    with open(file_path, 'w') as f:

        # conv1
        switch_layer(f, 'conv1') # switch to conv1
        conv1_load_A(f) # LOAD_A for conv1
        conv1_load_C(f) # LOAD_C for conv1

        # conv2
        switch_layer(f, 'conv2') # switch to conv2
        conv2_load_A(f) # LOAD_A for conv2
        conv2_load_B(f, ref) # LOAD_B for conv2

        # fc1
        switch_layer(f, 'fc1') # switch to fc1
        fc1_load_A_C(f, ref) # LOAD_A and LOAD_C for fc1

        # fc2
        switch_layer(f, 'fc2') # switch to fc2
        fc2_load_A_C(f, ref) # LOAD_A and LOAD_C for fc2
        final_result(f, ref) # result

if __name__ == "__main__":
    dcache_gen('../../../../rtl/cv32e40p/fpga/tb/dcache.hex', ref=False)
    dcache_gen('dcache_ref.hex', ref=True)