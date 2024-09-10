import re

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
import glob
from brevitas.quant.scaled_int import Int8BiasPerTensorFloatInternalScaling as INT8Bias
from brevitas.quant.scaled_int import Int8WeightPerTensorFloat as INT8Weight

import tonic
import tonic.transforms as transforms

import optuna

from Datasets import *
from Config_and_Functions import *
from Net import *

study_path = f"./NMNIST Binary/Sparse Fast Sigmoid 08_19_2024-01_49_13_AM"
db_name = "Sparse Fast Sigmoid"
storage_name = "sqlite:///{}/{}.db".format(study_path, db_name)

study = optuna.load_study(study_name=db_name, storage=storage_name)


# Sort trials based on their objective value and get the top 7
top_7_trials = sorted(study.trials, key=lambda t: t.value, reverse=True)[:7]


# Sort the trials by slope value
top_7_trials = sorted(top_7_trials, key=lambda t: t.params["slope"], reverse=False)


# Print data to copy to Excel
for trial in top_7_trials:
    print(f'{trial.number} {trial.params["slope"]} {trial.value:0.2f}%')

print()
model_list = glob.glob(f'{study_path}/*.pth')
for trial in top_7_trials:
    model_path = next((model for model in model_list if f' T{trial.number} ' in model), None)

    matches = re.findall('(?<=\()(.*?)(?=\))', model_path)

    if "INT4" in model_path:
        data_type = "INT4"
        is_quantized = True
    elif "FP32" in model_path:
        data_type = "FP32"
        is_quantized = False
    else:
        print("Unrecognized data type")
        exit(-1)

    data_path = '/Users/jlopezramos/Documents/Deep Learning/datasets'

    model_name = model_path.rsplit('\\', 1)[1]
    print(model_name)
    print(data_type)

    # Extract the dataset string from the model name and loads the matching class
    dataset_str = model_name.split(" ", 1)[0]
    dataset = eval(dataset_str+"(config, data_path)")

    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")

    net = Net(config, dataset, is_quantized, 0).to(device)

    if os.path.exists(model_path):
        net.load_state_dict(torch.load(model_path, map_location=device))
        print("Model loaded successfully")
    else:
        print("Model not found")
        exit(-5)

    current_accuracy = test(config, net, dataset, device)
    print(f"Curent acc: {current_accuracy:0.2f}% \n")
    print(f'{trial.number}: ({matches[-1]}) Slope({matches[1]})')

    ######################### input image ########################
    sampleloader = dataset.GetSampleLoader()
    d_it, labels = next(iter(sampleloader))
    sample = d_it.to(device)

    test_mode = False

    with torch.no_grad():
        net.eval()

        spikes, time_steps, spike_layers = net(sample, True)
        count_avg_spikes(spike_layers)
        print('\n\n')
        # print(spikes)
        #
        # if (spikes[324] == 1):
        #     print("one")



exit(0)