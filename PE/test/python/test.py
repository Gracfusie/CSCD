import torch
import torch.nn as nn
import torch.nn.functional as F
import numpy as np

# Calculate the correct output

def load_hex_weights(file_path):
    # Read the file as a string of hex values
    with open(file_path, 'r') as f:
        data = f.read().splitlines()
    
    # Convert each space-separated hex string to integer
    weights = []
    for line in data:
        for val in line.split():
            # Handle two's complement for negative numbers in int8 range
            int_val = int(val, 16)  # Convert hex string to integer
            if int_val > 127:  # If the value is above 127, it should be a negative number
                int_val -= 256  # Convert to signed 8-bit integer (two's complement)
            weights.append(int_val)
    
    return np.array(weights, dtype=np.int8)

def load_sample_input(file_path):
    with open(file_path, "r") as f:
        data = f.read().split()
    data = np.array(list(map(int, data)), dtype=np.int32)
    data = data.reshape(5, 1, 16, 15)
    return data

def mac_24bit(input_patch, weight, bias=None, relu=True, clip=True):
    inp = input_patch.to(torch.int32)
    # print(inp,inp.shape)
    w = weight.to(torch.int32)
    # print(w,w.shape)
    acc = torch.sum(inp * w, dim=(1, 2, 3), keepdim=False)
    # print(acc)
    if bias is not None:
        acc += bias.to(torch.int32)
    #acc = torch.clamp(acc, -2**23, 2**23-1)
    #print(acc)
    # print(acc)
    if relu:
        acc = torch.clamp(acc, 0, 2**23-1)
    else:
        acc = torch.clamp(acc, -2**23, 2**23-1)
    if clip:
        acc = ((acc ) & 0xFF).to(torch.uint8)
    # print(acc)
    # print(out8)
    return acc

def quantized_conv2d(x, weight, bias, stride=1, relu=True, clip=True):
    N, Cin, H, W = x.shape
    Cout, _, Kh, Kw = weight.shape
    Hout = (H - Kh) // stride + 1
    Wout = (W - Kw) // stride + 1
    out = torch.zeros((N, Cout, Hout, Wout), dtype=torch.int32)
    for n in range(N):
        for co in range(Cout):
            for i in range(Hout):
                for j in range(Wout):
                    patch = x[n, :, i:i+Kh, j:j+Kw]
                    val = mac_24bit(patch, weight[co:co+1], bias[co], relu=relu, clip=clip)
                    out[n, co, i, j] = val
    return out

def quantized_conv3d(x, weight, bias, stride=1, clip=True):
    N, Cin, H, W = x.shape  # 3D input
    _, Kd, Kh, Kw = weight.shape  # 3D filter
    Cout = (Cin - Kd) // stride + 1
    Hout = (H - Kh) // stride + 1
    Wout = (W - Kw) // stride + 1
    out = torch.zeros((N, Cout, Hout, Wout), dtype=torch.uint8)
    for n in range(N):
        for co in range(Cout):
            for i in range(Hout):
                for j in range(Wout):
                    patch = x[n, co:co+Kd, i:i+Kh, j:j+Kw]
                    val = mac_24bit(patch, weight[co:co+1], bias[co], clip=clip)
                    out[n, co, i, j] = val
    return out

def load_out_npu(data, start, end, n, c, h, w):
    out_npu = []
    for i in range(start, end):
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
    out_npu = out_npu.reshape(n, w, h, c)
    # 转置
    out_npu = out_npu.transpose(0, 3, 2, 1)
    out_npu = torch.from_numpy(out_npu).to(torch.uint8)
    return out_npu

def compare_outputs(out_py, out_npu):
    print("Shape of Output from Python:", out_py.shape)
    print("Shape of Output from NPU:   ", out_npu.shape)
    if torch.equal(out_py, out_npu):
        print("The outputs from Python and NPU match!")
    else:
        print("The outputs from Python and NPU do not match.")
        print(out_npu)
        # Find and print the differences
        # differences = torch.nonzero(out_py != out_npu)
        # for idx in differences:
        #     print(f"Mismatch at index {tuple(idx.tolist())}: Python={out_py[tuple(idx.tolist())]}, NPU={out_npu[tuple(idx.tolist())]}")
        # print(f"Total mismatches: {len(differences)}")

conv1_weight = load_hex_weights('handout_new/data/conv1_weight.txt')
conv1_weight = conv1_weight.reshape(10, 1, 3, 3)
conv1_bias = np.zeros(10, dtype=np.int8)

sample_input = load_sample_input('handout_new/data/sample_input.txt') # shape: (5, 1, 16, 15)
sample_input = sample_input[0:1, :, :, :] # shape: (1, 1, 16, 15)

q_conv1_w = torch.tensor(conv1_weight, dtype=torch.int8)
q_conv1_b = torch.tensor(conv1_bias, dtype=torch.int8)
q_sample_input = torch.tensor(sample_input, dtype=torch.uint8) # shape: (1, 1, 16, 15)

out_conv1_py = quantized_conv2d(q_sample_input, q_conv1_w, q_conv1_b, relu=True, clip=True) # shape: (1, 10, 14, 13)

conv2_weight = load_hex_weights('handout_new/data/conv2_weight.txt')
conv2_weight = conv2_weight.reshape(10, 1, 3, 3)
conv2_bias = np.zeros(10, dtype=np.int8)

q_conv2_w = torch.tensor(conv2_weight, dtype=torch.int8)
q_conv2_b = torch.tensor(conv2_bias, dtype=torch.int8)
q_conv2_input = out_conv1_py # shape: (1, 10, 14, 13)

out_conv2_py = torch.zeros((1, 10, 12, 11), dtype=torch.int32)
for i in range(10):
    out_conv2_py[:, i:i+1, :, :] = quantized_conv2d(q_conv2_input[:, i:i+1, :, :], q_conv2_w[i:i+1, :, :, :], q_conv2_b[i:i+1], relu=False, clip=False)

conv2_weight_2 = conv2_weight.reshape(1, 10, 3, 3)
q_conv2_w_2 = torch.tensor(conv2_weight_2, dtype=torch.int8)

out_conv2_relu_py = quantized_conv3d(out_conv1_py, q_conv2_w_2, q_conv2_b, stride=1, clip=True)

print(out_conv2_relu_py.shape)

out_conv2_relu_npu = torch.zeros((1, 1, 12, 11), dtype=torch.uint8)
for row in range(12):
    for col in range(11):
        inp = out_conv2_py[0, 0:10, row, col].to(torch.int32)
        acc = inp.sum()
        acc = torch.clamp(acc, 0, 2**23-1)
        acc = (acc & 0xFF).to(torch.uint8)
        out_conv2_relu_npu[0, 0, row, col] = acc

compare_outputs(out_conv2_relu_py, out_conv2_relu_npu)

# # Compare the outputs
# print('layer: conv1')
# compare_outputs(out_conv1_py, out_conv1_npu)
# print('layer: conv2')
# compare_outputs(out_conv2_py, out_conv2_npu)
