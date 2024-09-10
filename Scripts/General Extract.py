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
from snntorch import utils
import snntorch.functional as SF
import glob
from brevitas.quant.scaled_int import Int8BiasPerTensorFloatInternalScaling as INT8Bias
from brevitas.quant.scaled_int import Int8WeightPerTensorFloat as INT8Weight

import tonic
import tonic.transforms as transforms

from Config_and_Functions import *
from Datasets import *
from Net import Net

model_name = "DVSGesture T5 TW300K CS(0.25) SL(4.0) INT4 (71.59%) EP178 07_22_2024-07_41_30_AM"
model_path = ("C:/Users/jlopezramos/Desktop/PyCharmProjects/DVS/DVSGesture Binary/ATAN 07_22_2024-12_52_42_AM/"
              + model_name + ".pth")

weight_folder = model_name[:model_name.index(" EP")]
print(weight_folder)

# Possible values for the EC_Size. (Factors of the layers size)
conv_1_1 = 64  # 2, 4, 8, 16, 32, 64
conv_1_2 = 28  # 2, 4, 7, 14, 28
conv_2_1 = 48  # 2, 3, 4, 6, 8, 12, 16, 24, 48
conv_2_2 = 54  # 2, 3, 6, 9, 18, 27, 54
conv_3_1 = 120  # 2, 3, 4, 5, 6, 8, 10, 12, 15, 20, 24, 30, 40, 60, 120
conv_3_2 = 126  # 2, 3, 6, 7, 9, 14, 18, 21, 42, 63, 126
conv_3_3 = 140  # 2, 4, 5, 7, 10, 14, 20, 28, 35, 70, 140
fc_1 = 56  # 2, 4, 7, 8, 14, 19, 28, 38, 56, 76, 133, 152, 266, 532, 1064
fc_2 = 50  # 2, 4, 5, 8, 10, 20, 25, 40, 50, 100, 125, 200, 250, 500, 1000

if "INT4" in model_path:
    data_type = "INT4"
    is_quantized = True
elif "FP32" in model_path:
    data_type = "FP32"
    is_quantized = False
else:
    print("Unrecognized data type")
    exit(-1)

print(data_type)

######################## model dir ########################

# data_path = '/Users/School/Documents/Machine Learning/datasets'
data_path = '/Users/jlopezramos/Documents/Deep Learning/datasets'


device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
device_cpu = torch.device("cpu")

# Extract surrogate name from model path
surrogate_str = model_path.rsplit('/', 2)[1].rsplit(" ", 1)[0]

# Extract the dataset string from the model name and loads the matching class
dataset_str = model_name.split(" ", 1)[0]
dataset = eval(dataset_str+"(config, data_path)")

dir_name = 'C:/Users/jlopezramos/Desktop/Vivado Projects/Models/{}/{}/{}_{{{}_{}_{}_{}_{}_{}_{}_{}_{}}}'.format(
    dataset_str, surrogate_str,
    weight_folder,
    conv_1_1, conv_1_2,
    conv_2_1, conv_2_2,
    conv_3_1, conv_3_2, conv_3_3,
    fc_1, fc_2)

FC1_SIZE = 1064
FC2_SIZE = config['pop_size_factor'] * dataset.num_classes

net = Net(config, dataset, is_quantized, 0).to(device)

if (os.path.exists(model_path)):
    net.load_state_dict(torch.load(model_path, map_location=device))
    print("Model loaded successfully")
else:
    print("Model not found")
    print(model_path)
    exit(-5)

current_accuracy = test(config, net, dataset, device)  # test_accuracy(testloader, net, config['num_steps'], population_code=True)
print(f"Curent acc: {current_accuracy:0.2f}% \n")


######################## Utility Funcs ########################
def save_weights_and_biases(conv_layer, dir_name, l, n):
    with torch.no_grad():
        if (is_quantized):
            weights = conv_layer.int_weight()
            biases = conv_layer.int_bias()
        else:
            weights = conv_layer.weight.data
            biases = conv_layer.bias.data

        # Create a dictionary to store weights and biases for each file
        file_data = {i: [] for i in range(n)}

        for i, (filter_tensor, bias) in enumerate(zip(weights, biases)):
            file_index = i % n  # This will ensure the desired distribution

            current_weights = filter_tensor.cpu().numpy().flatten()[::-1].tolist()
            current_weights.reverse()
            current_weights.append(bias.item())
            file_data[file_index].append(current_weights)

        for file_index, weights_set in file_data.items():
            file_name = f"conv{l}_nc{file_index}.txt"
            full_path = os.path.join(dir_name, file_name)

            with open(full_path, 'w') as file:
                for idx, w in enumerate(weights_set):
                    file.write('\n'.join(map(str, w)))
                    if idx != len(weights_set) - 1:  # Avoid writing extra newline characters after the last filter
                        file.write("\n")


def create_macro_file(net, dir_name, is_quantized, conv_1_1_ec_size, conv_1_2_ec_size,
                      conv_2_1_ec_size, conv_2_2_ec_size,
                      conv_3_1_ec_size, conv_3_2_ec_size, conv_3_3_ec_size, fc1_ec_size, fc2_ec_size,
                      FC2_size, time_steps):
    macro_path = f"{dir_name}/macros.txt"

    with open(macro_path, 'w') as file:
        file.write(f'`define model_directory "{dir_name}"\n\n')

        file.write(f"`define conv_1_1_ec_size {conv_1_1_ec_size}\n")
        file.write(f"`define conv_1_2_ec_size {conv_1_2_ec_size}\n")
        file.write(f"`define conv_2_1_ec_size {conv_2_1_ec_size}\n")
        file.write(f"`define conv_2_2_ec_size {conv_2_2_ec_size}\n")
        file.write(f"`define conv_3_1_ec_size {conv_3_1_ec_size}\n")
        file.write(f"`define conv_3_2_ec_size {conv_3_2_ec_size}\n")
        file.write(f"`define conv_3_3_ec_size {conv_3_3_ec_size}\n")
        file.write(f"`define fc1_ec_size {fc1_ec_size}\n")
        file.write(f"`define fc2_ec_size {fc2_ec_size}\n\n")
        
        file.write(f"`define FC2_size {FC2_size}\n")
        file.write(f"`define time_steps {time_steps}\n\n")

        if is_quantized:
            weight_sfactor = net.Qconv1_1.quant_weight_scale().cpu().detach().numpy()
            file.write(f"`define w_sfactor_1_1 {str(weight_sfactor)}\n")
            weight_sfactor = net.Qconv1_2.quant_weight_scale().cpu().detach().numpy()
            file.write(f"`define w_sfactor_1_2 {str(weight_sfactor)}\n")
            weight_sfactor = net.Qconv2_1.quant_weight_scale().cpu().detach().numpy()
            file.write(f"`define w_sfactor_2_1 {str(weight_sfactor)}\n")
            weight_sfactor = net.Qconv2_2.quant_weight_scale().cpu().detach().numpy()
            file.write(f"`define w_sfactor_2_2 {str(weight_sfactor)}\n")
            weight_sfactor = net.Qconv3_1.quant_weight_scale().cpu().detach().numpy()
            file.write(f"`define w_sfactor_3_1 {str(weight_sfactor)}\n")
            weight_sfactor = net.Qconv3_2.quant_weight_scale().cpu().detach().numpy()
            file.write(f"`define w_sfactor_3_2 {str(weight_sfactor)}\n")
            weight_sfactor = net.Qconv3_3.quant_weight_scale().cpu().detach().numpy()
            file.write(f"`define w_sfactor_3_3 {str(weight_sfactor)}\n")
            weight_sfactor = net.Qfc1.quant_weight_scale().cpu().detach().numpy()
            file.write(f"`define w_sfactor_fc1 {str(weight_sfactor)}\n")
            weight_sfactor = net.Qfc2.quant_weight_scale().cpu().detach().numpy()
            file.write(f"`define w_sfactor_fc2 {str(weight_sfactor)}\n")

            bias_sfactor = net.Qconv1_1.quant_bias_scale().cpu().detach().numpy()
            file.write(f"`define b_sfactor_1_1 {str(bias_sfactor)}\n")
            bias_sfactor = net.Qconv1_2.quant_bias_scale().cpu().detach().numpy()
            file.write(f"`define b_sfactor_1_2 {str(bias_sfactor)}\n")
            bias_sfactor = net.Qconv2_1.quant_bias_scale().cpu().detach().numpy()
            file.write(f"`define b_sfactor_2_1 {str(bias_sfactor)}\n")
            bias_sfactor = net.Qconv2_2.quant_bias_scale().cpu().detach().numpy()
            file.write(f"`define b_sfactor_2_2 {str(bias_sfactor)}\n")
            bias_sfactor = net.Qconv3_1.quant_bias_scale().cpu().detach().numpy()
            file.write(f"`define b_sfactor_3_1 {str(bias_sfactor)}\n")
            bias_sfactor = net.Qconv3_2.quant_bias_scale().cpu().detach().numpy()
            file.write(f"`define b_sfactor_3_2 {str(bias_sfactor)}\n")
            bias_sfactor = net.Qconv3_3.quant_bias_scale().cpu().detach().numpy()
            file.write(f"`define b_sfactor_3_3 {str(bias_sfactor)}\n")
            bias_sfactor = net.Qfc1.quant_bias_scale().cpu().detach().numpy()
            file.write(f"`define b_sfactor_fc1 {str(bias_sfactor)}\n")
            bias_sfactor = net.Qfc2.quant_bias_scale().cpu().detach().numpy()
            file.write(f"`define b_sfactor_fc2 {str(bias_sfactor)}\n")

            weight_zpt = net.Qconv1_1.quant_weight_zero_point().cpu().detach().numpy()
            file.write(f"`define w_zpt_1_1 {str(weight_zpt)}\n")
            weight_zpt = net.Qconv1_2.quant_weight_zero_point().cpu().detach().numpy()
            file.write(f"`define w_zpt_1_2 {str(weight_zpt)}\n")
            weight_zpt = net.Qconv2_1.quant_weight_zero_point().cpu().detach().numpy()
            file.write(f"`define w_zpt_2_1 {str(weight_zpt)}\n")
            weight_zpt = net.Qconv2_2.quant_weight_zero_point().cpu().detach().numpy()
            file.write(f"`define w_zpt_2_2 {str(weight_zpt)}\n")
            weight_zpt = net.Qconv3_1.quant_weight_zero_point().cpu().detach().numpy()
            file.write(f"`define w_zpt_3_1 {str(weight_zpt)}\n")
            weight_zpt = net.Qconv3_2.quant_weight_zero_point().cpu().detach().numpy()
            file.write(f"`define w_zpt_3_2 {str(weight_zpt)}\n")
            weight_zpt = net.Qconv3_3.quant_weight_zero_point().cpu().detach().numpy()
            file.write(f"`define w_zpt_3_3 {str(weight_zpt)}\n")
            weight_zpt = net.Qfc1.quant_weight_zero_point().cpu().detach().numpy()
            file.write(f"`define w_zpt_fc1 {str(weight_zpt)}\n")
            weight_zpt = net.Qfc2.quant_weight_zero_point().cpu().detach().numpy()
            file.write(f"`define w_zpt_fc2 {str(weight_zpt)}\n")

            b_zpt = net.Qconv1_1.quant_bias_zero_point().cpu().detach().numpy()
            file.write(f"`define b_zpt_1_1 {str(b_zpt)}\n")
            b_zpt = net.Qconv1_2.quant_bias_zero_point().cpu().detach().numpy()
            file.write(f"`define b_zpt_1_2 {str(b_zpt)}\n")
            b_zpt = net.Qconv2_1.quant_bias_zero_point().cpu().detach().numpy()
            file.write(f"`define b_zpt_2_1 {str(b_zpt)}\n")
            b_zpt = net.Qconv2_2.quant_bias_zero_point().cpu().detach().numpy()
            file.write(f"`define b_zpt_2_2 {str(b_zpt)}\n")
            b_zpt = net.Qconv3_1.quant_bias_zero_point().cpu().detach().numpy()
            file.write(f"`define b_zpt_3_1 {str(b_zpt)}\n")
            b_zpt = net.Qconv3_2.quant_bias_zero_point().cpu().detach().numpy()
            file.write(f"`define b_zpt_3_2 {str(b_zpt)}\n")
            b_zpt = net.Qconv3_3.quant_bias_zero_point().cpu().detach().numpy()
            file.write(f"`define b_zpt_3_3 {str(b_zpt)}\n")
            b_zpt = net.Qfc1.quant_bias_zero_point().cpu().detach().numpy()
            file.write(f"`define b_zpt_fc1 {str(b_zpt)}\n")
            b_zpt = net.Qfc2.quant_bias_zero_point().cpu().detach().numpy()
            file.write(f"`define b_zpt_fc2 {str(b_zpt)}\n")

        else:
            file.write("`define w_sfactor_1_1 1.0 \n"
                       "`define w_sfactor_1_2 1.0\n"
                       "`define w_sfactor_2_1 1.0\n"
                       "`define w_sfactor_2_2 1.0\n"
                       "`define w_sfactor_3_1 1.0\n"
                       "`define w_sfactor_3_2 1.0\n"
                       "`define w_sfactor_3_3 1.0\n"
                       "`define w_sfactor_fc1 1.0\n"
                       "`define w_sfactor_fc2 1.0\n"
                       "`define b_sfactor_1_1 1.0\n"
                       "`define b_sfactor_1_2 1.0\n"
                       "`define b_sfactor_2_1 1.0\n"
                       "`define b_sfactor_2_2 1.0\n"
                       "`define b_sfactor_3_1 1.0\n"
                       "`define b_sfactor_3_2 1.0\n"
                       "`define b_sfactor_3_3 1.0\n"
                       "`define b_sfactor_fc1 1.0\n"
                       "`define b_sfactor_fc2 1.0\n"
                       "`define w_zpt_1_1 0.0\n"
                       "`define w_zpt_1_2 0.0\n"
                       "`define w_zpt_2_1 0.0\n"
                       "`define w_zpt_2_2 0.0\n"
                       "`define w_zpt_3_1 0.0\n"
                       "`define w_zpt_3_2 0.0\n"
                       "`define w_zpt_3_3 0.0\n"
                       "`define w_zpt_fc1 0.0\n"
                       "`define w_zpt_fc2 0.0\n"
                       "`define b_zpt_1_1 0.0\n"
                       "`define b_zpt_1_2 0.0\n"
                       "`define b_zpt_2_1 0.0\n"
                       "`define b_zpt_2_2 0.0\n"
                       "`define b_zpt_3_1 0.0\n"
                       "`define b_zpt_3_2 0.0\n"
                       "`define b_zpt_3_3 0.0\n"
                       "`define b_zpt_fc1 0.0\n"
                       "`define b_zpt_fc2 0.0")

        print(f'`include "{macro_path}"\n')


def parse_lin(lin):
    result_row = ''.join(map(str, map(int, lin)))
    return result_row


# Rate encoding code
os.makedirs(dir_name, exist_ok=True)
fc_dir = 'weights'
full_path_fc = os.path.join(dir_name, fc_dir)  # Corrected path for the 'fc' subdirectory
if os.path.exists(full_path_fc):
    shutil.rmtree(full_path_fc)
os.makedirs(full_path_fc, exist_ok=True)
print_net = os.path.join(dir_name, 'net.txt')
with open(print_net, 'w') as file:
    file.write(str(net))
    # file.write(dataset_name)

######################### spikes. ########################
full_path = os.path.join(dir_name, 'spk_in.txt')
spk_in_data = open(full_path, "w")
torch.manual_seed(1159988220)

sampleloader = dataset.GetSampleLoader()
d_it, labels = next(iter(sampleloader))
sample = d_it.to(device)
with torch.no_grad():
    net.eval()

    outputs, time_steps, spike_layers = net(sample, True)
    count_total_spikes(spike_layers)
    print('\n\n')

fltnd = sample.reshape(sample.size(0) * 2, int(64 * 64))

for lin in fltnd:
    result_row = parse_lin(lin.cpu().numpy())
    spk_in_data.write(result_row + '\n')

save_weights_and_biases(net.Qconv1_1, full_path_fc, "1_1", conv_1_1)
save_weights_and_biases(net.Qconv1_2, full_path_fc, '1_2', conv_1_2)
save_weights_and_biases(net.Qconv2_1, full_path_fc, "2_1", conv_2_1)
save_weights_and_biases(net.Qconv2_2, full_path_fc, '2_2', conv_2_2)
save_weights_and_biases(net.Qconv3_1, full_path_fc, "3_1", conv_3_1)
save_weights_and_biases(net.Qconv3_2, full_path_fc, '3_2', conv_3_2)
save_weights_and_biases(net.Qconv3_3, full_path_fc, '3_3', conv_3_3)

create_macro_file(net, dir_name, is_quantized, conv_1_1, conv_1_2, conv_2_1, conv_2_2, conv_3_1, conv_3_2, conv_3_3,
                  fc_1, fc_2, config["pop_size_factor"]*dataset.num_classes, time_steps)

NEURAL_SIZE_1 = int(FC1_SIZE / fc_1)
if is_quantized:
    FC1_layer_weights = net.Qfc1.int_weight()
    FC1_layer_biases = net.Qfc1.int_bias()
else:
    FC1_layer_weights = net.Qfc1.weight.data
    FC1_layer_biases = net.Qfc1.bias.data

for i in range(0, len(FC1_layer_weights), NEURAL_SIZE_1):
    with open(os.path.join(full_path_fc, f'fc1_nc{i // NEURAL_SIZE_1}.txt'), 'w') as file:
        for j in range(i, min(i + NEURAL_SIZE_1, len(FC1_layer_weights))):  # Up to NEURAL_SIZE neurons in this file
            weights = FC1_layer_weights[j].data.cpu().numpy()
            bias_sfactor = FC1_layer_biases[j].data.cpu().numpy()

            # Write the floating-point numbers for the weights
            file.write('\n'.join(map(str, weights)))

            # Write the bias
            file.write(f'\n{bias_sfactor}\n')

NEURAL_SIZE_2 = int(FC2_SIZE / fc_2)

if is_quantized:
    FC2_layer_weights = net.Qfc2.int_weight()
    FC2_layer_biases = net.Qfc2.int_bias()
else:
    FC2_layer_weights = net.Qfc2.weight.data
    FC2_layer_biases = net.Qfc2.bias.data

for i in range(0, len(FC2_layer_weights), NEURAL_SIZE_2):
    with open(os.path.join(full_path_fc, f'fc2_nc{i // NEURAL_SIZE_2}.txt'), 'w') as file:
        for j in range(i, min(i + NEURAL_SIZE_2, len(FC2_layer_weights))):  # Up to NEURAL_SIZE neurons in this file
            weights = FC2_layer_weights[j].data.cpu().numpy()
            bias_sfactor = FC2_layer_biases[j].data.cpu().numpy()

            # Write the floating-point numbers for the weights
            file.write('\n'.join(map(str, weights)))

            # Write the bias
            file.write(f'\n{bias_sfactor}\n')

exit(0)