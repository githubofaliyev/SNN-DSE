import torch, torch.nn as nn
import snntorch as snn
import brevitas.nn as qnn
from snntorch import surrogate
import torch.nn.functional as F
import snntorch.functional as SF
import os
import numpy as np
from snntorch import spikegen
import numpy as np
import time
import shutil
from torch.utils.data import DataLoader
from torchvision import datasets, transforms
from snntorch import utils
import snntorch.functional as SF
import glob
from brevitas.quant.scaled_int import Int8BiasPerTensorFloatInternalScaling as INT8Bias
from brevitas.quant.scaled_int import Int8WeightPerTensorFloat as INT8Weight

from Net import *
from Datasets import *
from Functions import *
from Configs import config
from Net import *

model_name = "model_file_name"
model_path = os.path.join("./model_folder/", model_name + ".pth")

data_path = "./datasets/"
dataset = CIFAR10(config, data_path)
FC1_SIZE = 1064


conv_1_1 = 1  # Possible values for the EC_Size. (Factors of the layers size)
conv_1_2 = 1  # 2, 4, 7, 8, 14, 16, 28, 56, 112
conv_2_1 = 1  # 2, 3, 4, 6, 8, 12, 16, 24, 32, 48, 64, 96, 192
conv_2_2 = 1  # 2, 3, 4, 6, 8, 9, 12, 18, 24, 27, 36, 54, 72, 108, 216
conv_3_1 = 1  # 2, 3, 4, 5, 6, 8, 10, 12, 15, 16, 20, 24, 30, 32, 40, 48, 60, 80, 96, 120, 160, 240, 480
conv_3_2 = 1  # 2, 3, 4, 6, 7, 8, 9, 12, 14, 18, 21, 24, 28, 36, 42, 56, 63, 72, 84, 126, 168, 252, 504
conv_3_3 = 1  # 2, 4, 5, 7, 8, 10, 14, 16, 20, 28, 35, 40, 56, 70, 80, 112, 140, 280, 560
fc_1 = 1  # 2, 4, 7, 8, 14, 19, 28, 38, 56, 76, 133, 152, 266, 532, 1064
fc_2 = 1  # 2, 4, 5, 8, 10, 20, 25, 40, 50, 100, 125, 200, 250, 500, 1000

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
# Extract the dataset string from the model name and loads the matching class
dataset_str = model_name.split(" ", 1)[0]
dir_name = './Extracted_Models/{}_{{{}_{}_{}_{}_{}_{}_{}_{}_{}}}'.format(
    dataset_str, conv_1_1, conv_1_2,
    conv_2_1, conv_2_2,
    conv_3_1, conv_3_2, conv_3_3,
    fc_1, fc_2)


device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
device_cpu = torch.device("cpu")

net = Net(config, dataset, weight_quant, bias_quant).to(device)

print(model_path)
if (os.path.exists(model_path)):
    net.load_state_dict(torch.load(model_path, map_location=device))
    print("Model loaded successfully")
else:
    print("Model not found")
    exit(-5)


current_accuracy = test(config, net, dataset, device)
print(f"Curent acc: {current_accuracy}% \n")


if os.path.exists(dir_name):
    shutil.rmtree(dir_name)
os.makedirs(dir_name, exist_ok=True)
dc_dir = 'dc_weights'  # dense core weights
sc_dir = 'sc_weights'  # sparse core weights
full_path_dc = os.path.join(dir_name, dc_dir)
full_path_sc = os.path.join(dir_name, sc_dir)
os.makedirs(full_path_dc, exist_ok=True)
os.makedirs(full_path_sc, exist_ok=True)

######################### input image ########################
sample_loader = dataset.GetSampleLoader()
d_it, _ = next(iter(sample_loader))
sample = d_it[0]
flat_image = sample.cpu().numpy().flatten().tolist()

img_file_name = "image.txt"
full_path = os.path.join(dir_name, img_file_name)
with open(full_path, 'w') as file:
    for value in flat_image:
        file.write(str(value))
        file.write("\n")
if "Rate" in model_path:
    sparse_core_weights_and_biases(net.Qconv1_1, full_path_sc, '1_1', conv_1_1, is_quantized)
else:
    dense_core_weights_and_biases(net.Qconv1_1, full_path_dc, "1_1", conv_1_1, is_quantized)

sparse_core_weights_and_biases(net.Qconv1_2, full_path_sc, '1_2', conv_1_2, is_quantized)
sparse_core_weights_and_biases(net.Qconv2_1, full_path_sc, "2_1", conv_2_1, is_quantized)
sparse_core_weights_and_biases(net.Qconv2_2, full_path_sc, '2_2', conv_2_2, is_quantized)
sparse_core_weights_and_biases(net.Qconv3_1, full_path_sc, "3_1", conv_3_1, is_quantized)
sparse_core_weights_and_biases(net.Qconv3_2, full_path_sc, '3_2', conv_3_2, is_quantized)
sparse_core_weights_and_biases(net.Qconv3_3, full_path_sc, '3_3', conv_3_3, is_quantized)

create_macro_file(net, dir_name, is_quantized, conv_1_1, conv_1_2, conv_2_1, conv_2_2, conv_3_1, conv_3_2, conv_3_3,
                  fc_1, fc_2)


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
    with open(os.path.join(full_path_sc, f'fc1_nc{i // NEURAL_SIZE_1}.txt'), 'w') as file:
        for j in range(i, min(i + NEURAL_SIZE_1, len(FC1_layer_weights))):  # Up to NEURAL_SIZE neurons in this file
            weights = FC1_layer_weights[j].data.cpu().numpy()
            bias_sfactor = FC1_layer_biases[j].data.cpu().numpy()

            # Write the floating-point numbers for the weights
            file.write('\n'.join(map(str, weights)))

            # Write the bias
            file.write(f'\n{bias_sfactor}\n')


NEURAL_SIZE_2 = int(dataset.pop_size / fc_2)
for i in range(0, len(FC2_layer_weights), NEURAL_SIZE_2):
    with open(os.path.join(full_path_sc, f'fc2_nc{i // NEURAL_SIZE_2}.txt'), 'w') as file:
        for j in range(i, min(i + NEURAL_SIZE_2, len(FC2_layer_weights))):  # Up to NEURAL_SIZE neurons in this file
            weights = FC2_layer_weights[j].data.cpu().numpy()
            bias_sfactor = FC2_layer_biases[j].data.cpu().numpy()

            # Write the floating-point numbers for the weights
            file.write('\n'.join(map(str, weights)))

            # Write the bias
            file.write(f'\n{bias_sfactor}\n')

exit(0)
