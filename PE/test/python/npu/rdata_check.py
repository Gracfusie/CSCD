import torch
import torch.nn as nn
import torch.nn.functional as F
import numpy as np

def load_out_npu_1(data, start, end, n, c, h, w):
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

def load_out_npu_2(data, start, end, n, c, h, w):
    out_npu = []
    for i in range(start, end):
        data_3 = data[i][16:24]
        if (i % 3 == 2):
            out_npu.append(int(data_3, 2))
    out_npu = np.array(out_npu)
    out_npu = out_npu.reshape(n, w, h, c)
    # 转置
    out_npu = out_npu.transpose(0, 3, 2, 1)
    out_npu = torch.from_numpy(out_npu).to(torch.uint8)
    return out_npu

def compare_outputs(out_py, out_npu):
    # print("Shape of Output from Python:", out_py.shape)
    # print("Shape of Output from NPU:   ", out_npu.shape)
    if torch.equal(out_py, out_npu):
        print("The outputs from Python and NPU match!")
    else:
        print("The outputs from Python and NPU do not match.")
        print(out_py)
        print(out_npu)
        # Find and print the differences
        # differences = torch.nonzero(out_py != out_npu)
        # for idx in differences:
        #     print(f"Mismatch at index {tuple(idx.tolist())}: Python={out_py[tuple(idx.tolist())]}, NPU={out_npu[tuple(idx.tolist())]}")
        # print(f"Total mismatches: {len(differences)}")

# Load the Python outputs
out_conv1_py = torch.load('../output_py.pt')['output_conv1']
out_conv2_im_py = torch.load('../output_py.pt')['output_conv2_im']
out_conv2_py = torch.load('../output_py.pt')['output_conv2']
out_fc1_py = torch.load('../output_py.pt')['output_fc1']
out_fc2_py = torch.load('../output_py.pt')['output_fc2']

# Load the NPU outputs
file_path = 'rdata_output.txt'
with open(file_path, 'r') as f:
    data = f.read().splitlines()

out_conv1_npu = load_out_npu_1(data, 0, 546, 1, 10, 14, 13)
out_conv2_im_npu = load_out_npu_1(data, 546, 942, 1, 10, 12, 11)
out_conv2_npu = load_out_npu_2(data, 546, 942, 1, 1, 12, 11)
out_fc1_npu = load_out_npu_1(data, 942, 945, 1, 10, 1, 1)[:, :, 0, 0]
out_fc2_npu = load_out_npu_1(data, 945, 948, 1, 10, 1, 1)[:, 0:1, 0, 0]

# Compare the outputs
print('layer: conv1')
compare_outputs(out_conv1_py, out_conv1_npu)
print('layer: conv2_im')
compare_outputs(out_conv2_im_py, out_conv2_im_npu)
print('layer: conv2')
compare_outputs(out_conv2_py, out_conv2_npu)
print('layer: fc1')
compare_outputs(out_fc1_py, out_fc1_npu)
print('layer: fc2')
compare_outputs(out_fc2_py, out_fc2_npu)
print('Final output:', out_fc2_npu)