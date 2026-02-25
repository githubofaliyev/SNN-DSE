import torch, torch.nn as nn
import snntorch as snn
import brevitas.nn as qnn
from snntorch import surrogate
import torch.nn.functional as F
import snntorch.functional as SF
import os
import numpy as np
from snntorch import spikegen
import time
import shutil
from torch.utils.data import DataLoader
from torchvision import datasets, transforms
from snntorch import utils
import glob
from brevitas.quant.scaled_int import Int8BiasPerTensorFloatInternalScaling as INT8Bias
from brevitas.quant.scaled_int import Int8WeightPerTensorFloat as INT8Weight

from Net import *
from Datasets import *
from Functions import *
from Configs import config

# name of the model .pth file. The extension is appended
model_name = "model_file_name" + ".pth"
model_path = os.path.join("./model_folder/", model_name)

name_without_date = model_name.split("__")[0]

data_path = "./datasets/"
dataset = DVSGesture(config, data_path)
FC1_SIZE = 1064

              # Possible values for the EC_Size. (Factors of the layer size)
conv_1_1 = 1  # 2, 4, 8, 16, 32, 64
conv_1_2 = 1  # 2, 4, 7, 14, 28
conv_2_1 = 1  # 2, 3, 4, 6, 8, 12, 16, 24, 48
conv_2_2 = 1  # 2, 3, 6, 9, 18, 27, 54
conv_3_1 = 1  # 2, 3, 4, 5, 6, 8, 10, 12, 15, 20, 24, 30, 40, 60, 120
conv_3_2 = 1  # 2, 3, 6, 7, 9, 14, 18, 21, 42, 63, 126
conv_3_3 = 1  # 2, 4, 5, 7, 10, 14, 20, 28, 35, 70, 140
fc_1 = 1      # 2, 4, 7, 8, 14, 19, 28, 38, 56, 76, 133, 152, 266, 532, 1064
fc_2 = 1      # factors of pop_size

model_dataset = name_without_date.split("_")[0]

if model_dataset != dataset.name:
    print("Model dataset doesn't match class dataset")
    print(f"Model dataset: {model_dataset}")
    print(f"Class dataset: {dataset.name}")
    exit(-2)

if "INT4" in model_path:
    data_type = "INT4"
    is_quantized = True
    weight_quant = INT8Weight
    bias_quant = INT8Bias
elif "FP32" in model_path:
    data_type = "FP32"
    is_quantized = False
    weight_quant = None
    bias_quant = None
else:
    print("Unrecognized data type")
    exit(-1)

print(data_type)

######################## model dir ########################
dataset_str = model_name.split(" ", 1)[0]
dir_name = './Extracted_Models/{}/{}_{{{}_{}_{}_{}_{}_{}_{}_{}_{}}}'.format(
    dataset_str, name_without_date, conv_1_1, conv_1_2,
    conv_2_1, conv_2_2,
    conv_3_1, conv_3_2, conv_3_3,
    fc_1, fc_2)

device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
device_cpu = torch.device("cpu")

net = Net(config, dataset, weight_quant, bias_quant).to(device)

print(os.path.abspath(model_path))
if (os.path.exists(model_path)):
    net.load_state_dict(torch.load(model_path, map_location=device))
    print("Model loaded successfully\n")
else:
    print("Model not found")
    exit(-5)

current_accuracy = test(config, net, dataset, device)
print(f"Curent acc: {current_accuracy:0.2f}% \n")

if os.path.exists(dir_name):
    shutil.rmtree(dir_name)
os.makedirs(dir_name, exist_ok=True)
weights_dir = 'weights'
full_path_wt = os.path.join(dir_name, weights_dir)
os.makedirs(full_path_wt, exist_ok=True)

######################### input sample ########################
sample_loader = dataset.GetSampleLoader()
d_it, _ = next(iter(sample_loader))

is_event = getattr(dataset, "is_event_encoded", False)

if is_event:
    # DVS event-encoded: d_it is (1, T, C, H, W), write spike frames
    sample = d_it[0]  # (T, C, H, W)
    full_path = os.path.join(dir_name, 'spk_in.txt')
    in_ch = dataset.input_channels
    frame_size = dataset.input_size * dataset.input_size
    with open(full_path, "w") as spk_in_data:
        for t in range(dataset.num_steps):
            for c in range(in_ch):
                frame = sample[t, c]
                if frame.shape[0] != dataset.input_size or frame.shape[1] != dataset.input_size:
                    frame = F.interpolate(frame.unsqueeze(0).unsqueeze(0),
                                          size=dataset.input_size, mode='nearest').squeeze()
                binary_frame = (frame > 0).int().flatten().cpu().numpy()
                spk_in_data.write(''.join(map(str, binary_frame)) + '\n')

    sparse_core_weights_and_biases(net.Qconv1_1, full_path_wt, '1_1', conv_1_1, is_quantized)

elif not dataset.is_rate_encoded:
    sample = d_it[0]
    flat_image = sample.cpu().numpy().flatten().tolist()
    img_file_name = "image.txt"
    full_path = os.path.join(dir_name, img_file_name)
    with open(full_path, 'w') as file:
        for value in flat_image:
            file.write(str(value))
            file.write("\n")

    dense_core_weights_and_biases(net.Qconv1_1, full_path_wt, "1_1", conv_1_1, is_quantized)

else:
    sample = d_it[0]
    full_path = os.path.join(dir_name, 'spk_in.txt')
    spk_in_data = open(full_path, "w")

    in_ch = getattr(dataset, "input_channels", 3)
    smpl = spikegen.rate(sample.unsqueeze(0), num_steps=dataset.num_steps)
    fltnd = smpl.reshape((dataset.num_steps * in_ch, int(dataset.input_size * dataset.input_size)))

    for lin in fltnd:
        result_row = parse_lin(lin.cpu().numpy())
        spk_in_data.write(result_row + '\n')
    spk_in_data.close()

    sparse_core_weights_and_biases(net.Qconv1_1, full_path_wt, '1_1', conv_1_1, is_quantized)

sparse_core_weights_and_biases(net.Qconv1_2, full_path_wt, '1_2', conv_1_2, is_quantized)
sparse_core_weights_and_biases(net.Qconv2_1, full_path_wt, "2_1", conv_2_1, is_quantized)
sparse_core_weights_and_biases(net.Qconv2_2, full_path_wt, '2_2', conv_2_2, is_quantized)
sparse_core_weights_and_biases(net.Qconv3_1, full_path_wt, "3_1", conv_3_1, is_quantized)
sparse_core_weights_and_biases(net.Qconv3_2, full_path_wt, '3_2', conv_3_2, is_quantized)
sparse_core_weights_and_biases(net.Qconv3_3, full_path_wt, '3_3', conv_3_3, is_quantized)

create_macro_file(net, dir_name, is_quantized, dataset, conv_1_1, conv_1_2, conv_2_1, conv_2_2, conv_3_1,
                  conv_3_2, conv_3_3, fc_1, fc_2, config=config)

NEURAL_SIZE_1 = int(FC1_SIZE / fc_1)
if is_quantized:
    FC1_layer_weights = net.Qfc1.int_weight()
    FC1_layer_biases = net.Qfc1.int_bias()

    FC2_layer_weights = net.Qfc2.int_weight()
    FC2_layer_biases = net.Qfc2.int_bias()
else:
    FC1_layer_weights = net.Qfc1.weight.data
    FC1_layer_biases = net.Qfc1.bias.data

    FC2_layer_weights = net.Qfc2.weight.data
    FC2_layer_biases = net.Qfc2.bias.data

for i in range(0, len(FC1_layer_weights), NEURAL_SIZE_1):
    with open(os.path.join(full_path_wt, f'fc1_nc{i // NEURAL_SIZE_1}.txt'), 'w') as file:
        for j in range(i, min(i + NEURAL_SIZE_1, len(FC1_layer_weights))):
            weights = FC1_layer_weights[j].data.cpu().numpy()
            bias_sfactor = FC1_layer_biases[j].data.cpu().numpy()

            file.write('\n'.join(map(str, weights)))
            file.write(f'\n{bias_sfactor}\n')

NEURAL_SIZE_2 = int(dataset.pop_size / fc_2)
for i in range(0, len(FC2_layer_weights), NEURAL_SIZE_2):
    with open(os.path.join(full_path_wt, f'fc2_nc{i // NEURAL_SIZE_2}.txt'), 'w') as file:
        for j in range(i, min(i + NEURAL_SIZE_2, len(FC2_layer_weights))):
            weights = FC2_layer_weights[j].data.cpu().numpy()
            bias_sfactor = FC2_layer_biases[j].data.cpu().numpy()

            file.write('\n'.join(map(str, weights)))
            file.write(f'\n{bias_sfactor}\n')

exit(0)
