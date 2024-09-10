import urllib.request
import torch, torch.nn as nn
import snntorch as snn
import brevitas.nn as qnn
from snntorch import utils
from snntorch import surrogate, spikegen
import torch.nn.functional as F
import snntorch.functional as SF

from torch.utils.data import DataLoader

import os
import random
import numpy as np
from datetime import datetime

import optuna

import sys
import logging

from Datasets import *
from Config_and_Functions import *
from Net import *


is_quantized = True

device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
print(f'Device: {device}')
print('==> Preparing data..')

# data_path = '/Users/School/Documents/Machine Learning/datasets'
data_path = '/Users/jlopezramos/Documents/Deep Learning/datasets'

dataset = DVSGesture(config, data_path)
def objective(trial, models_path):
    net = Net(config, dataset, is_quantized, 0, optuna_trial=trial).to(device)
    lr = trial.suggest_float('lr', 1e-7, 1e-1, log=True)
    best_accuracy = 0.0

    start_date_time_obj = datetime.now()
    start_date_time_str = datetime.now().strftime("%m_%d_%Y-%I_%M_%S_%p")

    experiment_name = f'{dataset.name} T{trial.number} TW{config["time_window"] / 1000:0.0f}K CS({config["conv_scaler"]}) lr({trial.params["lr"]})'
    if (is_quantized):
        experiment_name += f' INT{config["num_bits"]}'
    else:
        experiment_name += f' FP32'


    params = trial.params
    models_list = []
    os.makedirs(models_path, exist_ok=True)
    log = open(f'{models_path}/{experiment_name} {start_date_time_str}.log', 'w')
    log.write("Config\n")
    log.write(f'num_epochs:{config["num_epochs"]}, batch_size:{dataset.batch_size}, time_window:{config["time_window"]/1000:0.0f}K, '
              f'conv_scaler:{config["conv_scaler"]} MP1:{config["MP1"]}, MP2:{config["MP2"]}, MP3:{config["MP3"]}, pop_size_factor:{config["pop_size_factor"]}\n'
              f'Parameters: {trial.params}\n\n')

    print(f"=======Training Net=======\n======={experiment_name}======\n")
    log.write(f"=======Training Net=======\n======={experiment_name}======\n")

    # Train
    for epoch in range(config["num_epochs"]):
        log.flush()

        train(config, net, dataset, lr, device)

        # Test
        curr_accuracy = test(config, net, dataset, device)
        if curr_accuracy > best_accuracy:
            best_accuracy = curr_accuracy


            # Save the new model
            model_dir = f"{models_path}/{experiment_name} ({curr_accuracy:0.2f}%) EP{epoch} {start_date_time_str}.pth"
            torch.save(net.state_dict(), model_dir)
            models_list.append(model_dir)

            if (len(models_list) > 1):
                os.remove(models_list.pop(0))


        print(f"Epoch: {epoch} \tCurrent acc: {curr_accuracy:.2f}%, Best acc: {best_accuracy:0.2f}%,      Elapsed Time: {datetime.now() - start_date_time_obj}\n")
        log.write(f"Epoch: {epoch} \tCurrent acc: {curr_accuracy:.2f}%, Best acc: {best_accuracy:0.2f}%,      Elapsed Time: {datetime.now() - start_date_time_obj}\n")

        trial.report(curr_accuracy, epoch)

        torch.cuda.empty_cache()

        # Handle pruning based on the intermediate value.
        if trial.should_prune():
            raise optuna.exceptions.TrialPruned()

    log.write(f"Stopping after {config['num_epochs']} Epochs\n")
    log.close()

    return best_accuracy


start_date_time_str = datetime.now().strftime("%m_%d_%Y-%I_%M_%S_%p")
models_path = f'./Learning Rate/{dataset.name} Binary/FS {start_date_time_str}'
os.makedirs(models_path, exist_ok=True)

# Add stream handler of stdout to show the messages
optuna.logging.get_logger("optuna").addHandler(logging.StreamHandler(sys.stdout))
study_name = f"Learning Rate"  # Unique identifier of the study.
storage_name = "sqlite:///{}/{}.db".format(models_path, study_name)

study = optuna.create_study(study_name=study_name, storage=storage_name, direction="maximize",
                            pruner=optuna.pruners.MedianPruner(n_warmup_steps=50))
                            #pruner=optuna.pruners.HyperbandPruner(25, config["num_epochs"]))

# study.enqueue_trial({"beta": 0.3, "threshold": 0.89})
# study.enqueue_trial({"slope": 2.0})
# study.enqueue_trial({"slope": 1.0})
# study.enqueue_trial({"slope": 1.0})
# study.enqueue_trial({"slope": 3.0})
# study.enqueue_trial({"slope": 8.0})
# study.enqueue_trial({"slope": 4.0})
# study.enqueue_trial({"slope": 9.0})
# study.enqueue_trial({"slope": 19.0})
# study.enqueue_trial({"slope": 13.0})
# study.enqueue_trial({"slope": 27.0})
# study.enqueue_trial({"slope": 20.0})
# study.enqueue_trial({"slope": 38.0})
# study.enqueue_trial({"slope": 41.0})
# study.enqueue_trial({"slope": 48.0})
# study.enqueue_trial({"slope": 42.0})

study.optimize(lambda trial: objective(trial, models_path=models_path), n_trials=45)

pruned_trials = study.get_trials(deepcopy=False, states=[optuna.trial.TrialState.PRUNED])
complete_trials = study.get_trials(deepcopy=False, states=[optuna.trial.TrialState.COMPLETE])

print("Study statistics: ")
print("  Number of finished trials: ", len(complete_trials))
print("  Number of pruned trials: ", len(pruned_trials))


# Sort trials based on their objective value
sorted_trials = sorted(study.trials, key=lambda t: t.value, reverse=True)

# Get the top 10 trials
top_10_trials = sorted_trials[:10]

# Print information about the top 10 trials
for i, trial in enumerate(top_10_trials, 1):
    print(f"Rank {i}:")
    print(f"  Trial number: {trial.number}")
    print(f"  Objective value: {trial.value:0.2f}")
    print(f"  Parameters: {trial.params}")
    print()