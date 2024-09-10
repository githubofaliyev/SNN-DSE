import torch
import torch.nn as nn
import snntorch as snn
import brevitas.nn as qnn
from snntorch import surrogate, spikegen
import torch.nn.functional as F
import snntorch.functional as SF
import numpy as np

config = {
    "num_epochs": 200,  # Number of epochs to train for (per trial)
    "seed": 0,  # random seed

    # Quantization
    "num_bits": 4,  # Bit resolution

    # Network parameters
    "grad_clip": False,  # Whether to clip gradients
    "weight_clip": False,  # Whether to clip weights
    "batch_norm": True,  # Whether to use batch normalization
    "dropout": 0.19,  # Dropout rate
    "beta": 0.24,  # Decay rate parameter (beta)
    "threshold": 0.23,  # Threshold parameter (theta)
    "lr": 1.4e-3,  # Initial learning rate
    "slope": 1.0,  # Slope value (k)

    # Fixed params
    "time_window": 300e3,
    "correct_rate": 1.0,  # Correct rate
    "incorrect_rate": 0.0,  # Incorrect rate
    "betas": (0.9, 0.999),  # Adam optimizer beta values
    "t_0": 4690,  # Initial frequency of the cosine annealing scheduler
    "eta_min": 0,  # Minimum learning rate

    "conv_scaler": 0.25,
    "pop_size_factor": 100,
    "MP1": 2,
    "MP2": 2,
    "MP3": 4
}


def count_avg_spikes(spike_layers):
    for spike_train in spike_layers:
        spike_count = 0

        for step_train in spike_train:
            np_step_array = step_train.cpu().numpy().flatten()
            spike_count += np.sum(np_step_array)

        spike_count = round(spike_count / len(spike_train))

        print(spike_count)


def count_total_spikes(spike_layers):
    for spike_train in spike_layers:
        spike_count = 0

        for step_train in spike_train:
            np_step_array = step_train.cpu().numpy().flatten()
            spike_count += np.sum(np_step_array)

        spike_count = round(spike_count)

        print(spike_count)


def train(config, net, dataset, optuna_lr, device="cpu"):
    """Complete one epoch of training."""
    trainloader = dataset.GetTrainLoader()

    optimizer = torch.optim.Adam(net.parameters(),
                                 # lr=config["lr"], betas=config["betas"]
                                 lr=optuna_lr, betas=config["betas"]
                                 )
    scheduler = torch.optim.lr_scheduler.CosineAnnealingLR(optimizer,
                                                           T_max=config["t_0"],
                                                           eta_min=config["eta_min"],
                                                           last_epoch=-1
                                                           )
    criterion = SF.mse_count_loss(correct_rate=config["correct_rate"],
                                  incorrect_rate=config["incorrect_rate"],
                                  population_code=True, num_classes=dataset.num_classes
                                  )

    net.train()
    loss_accum = []
    lr_accum = []
    i = 0
    for data, labels in trainloader:
        data, labels = data.to(device), labels.to(device)
        spk_rec, step_size, _ = net(data)
        loss = criterion(spk_rec, labels)
        optimizer.zero_grad()
        loss.backward()

        ## Enable gradient clipping
        if config["grad_clip"]:
            nn.utils.clip_grad_norm_(net.parameters(), 1.0)

        ## Enable weight clipping
        if config["weight_clip"]:
            with torch.no_grad():
                for param in net.parameters():
                    param.clamp_(-1, 1)

        optimizer.step()
        # scheduler.step()
        loss_accum.append(loss.item() / step_size)
        lr_accum.append(optimizer.param_groups[0]["lr"])

    return loss_accum, lr_accum


def test(config, net, dataset, device="cpu"):
    """Calculate accuracy on full test set."""
    testloader = dataset.GetTestLoader()

    correct = 0
    total = 0
    with torch.no_grad():
        net.eval()
        for data in testloader:
            gestures, labels = data
            gestures, labels = gestures.to(device), labels.to(device)
            outputs, step_size, _ = net(gestures)
            accuracy = SF.accuracy_rate(outputs, labels, population_code=True, num_classes=dataset.num_classes)
            total += labels.size(0)
            correct += accuracy * labels.size(0)

    return 100 * correct / total
