import argparse
import os
import torch, torch.nn as nn
import snntorch as snn
from snntorch import surrogate
from snntorch import spikegen
import snntorch.functional as SF
from snntorch import backprop
from snntorch import utils
from torch.utils.data import DataLoader
from torchvision import datasets, transforms
from torch.utils.data import ConcatDataset

batch_size = 32
data_path='/Users/ilkinaliyev/Desktop/snntorch_main/workspace/datasets'
device = torch.device("mps" if torch.backends.mps.is_available() else "cpu") # Change this to cuda if GPU, mps set for Apple slicon
#print(device)

transform_not_augmented = transforms.Compose([
        transforms.ToTensor(),
        transforms.Normalize((0.4376821, 0.4437697, 0.47280442), (0.19803012, 0.20101562, 0.19703614)) # mean and std for SVHN to improve test acc.
    ])

ds_train = datasets.SVHN(data_path, split='train', download=True, transform=transform_not_augmented)
ds_test = datasets.SVHN(data_path, split='test', download=True, transform=transform_not_augmented)


# Create DataLoaders
train_loader = DataLoader(ds_train, batch_size=batch_size, shuffle=True)
test_loader = DataLoader(ds_test, batch_size=batch_size, shuffle=True)

parser = argparse.ArgumentParser(description='SNN Training Script')
parser.add_argument('--slp', type=float, default=0.25, help='Surrogate Slope')
args = parser.parse_args()

slp = args.slp 

num_steps = 18
beta = 0.25  # neuron decay rate
#grad = surrogate.atan(alpha=slp)
grad = surrogate.fast_sigmoid(slope=slp)
pop_outputs = 450 # for population coding in output layer

#  Initialize Network
net = nn.Sequential(nn.Conv2d(3, 32, 3),
                    nn.MaxPool2d(2),
                    snn.Leaky(beta=beta, threshold=1.0, spike_grad=grad, init_hidden=True),
                    nn.Conv2d(32, 32, 3),
                    nn.MaxPool2d(2),
                    snn.Leaky(beta=beta, threshold=1.0, spike_grad=grad, init_hidden=True),
                    nn.Flatten(),
                    nn.Linear(32*6*6, 256),
                    snn.Leaky(beta=beta, threshold=1.0, spike_grad=grad, init_hidden=True),
                    nn.Linear(256, pop_outputs),
                    snn.Leaky(beta=beta, threshold=1.0, spike_grad=grad, init_hidden=True, output=True)
                    ).to(device)

loss_fn = SF.mse_count_loss(correct_rate=1.0, incorrect_rate=0.0, population_code=True, num_classes=10) # works best in rate coding
optimizer = torch.optim.Adam(net.parameters(), lr=2e-3, betas=(0.9, 0.999))
scheduler = torch.optim.lr_scheduler.CosineAnnealingLR(optimizer, T_max=4690, eta_min=0, last_epoch=-1) # for faster convergence to optimal accuracy

def test_accuracy(data_loader, net, num_steps, population_code=False, num_classes=False):
  with torch.no_grad():
    total = 0
    acc = 0
    net.eval()

    data_loader = iter(data_loader)
    for data, targets in data_loader:
      data = data.to(device)
      targets = targets.to(device)
      utils.reset(net)
      spk_rec, _ = net(data)

      if population_code:
        acc += SF.accuracy_rate(spk_rec.unsqueeze(0), targets, population_code=True, num_classes=10) * spk_rec.size(1)
      else:
        acc += SF.accuracy_rate(spk_rec.unsqueeze(0), targets) * spk_rec.size(1)

      total += spk_rec.size(1)

  return acc/total

import gc

num_epochs = 25
best_accuracy = 0.0
best_epoch = 0

print("Training...")
for epoch in range(num_epochs):

    net = net
    dataloader = train_loader
    optimizer = optimizer
    criterion = loss_fn
    num_steps=num_steps
    time_var=False
    time_first=True
    regularization=False
    device = device
    K=num_steps


    # triggers global variables is_lapicque etc for neurons_dict
    # redo reset in training loop
    utils.reset(net=net)

    neurons_dict = {
        utils.is_lapicque: snn.Lapicque,
        utils.is_leaky: snn.Leaky,
        utils.is_synaptic: snn.Synaptic,
        utils.is_alpha: snn.Alpha,
        utils.is_rleaky: snn.RLeaky,
        utils.is_rsynaptic: snn.RSynaptic,
        utils.is_sconv2dlstm: snn.SConv2dLSTM,
        utils.is_slstm: snn.SLSTM,
    }

    # element 1: if true: spk, if false, mem
    # element 2: if true: time_varying_targets
    criterion_dict = {
        "mse_membrane_loss": [
            False,
            True,
        ],  # if time_var_target is true, need a flag to let mse_mem_loss
        # know when to re-start iterating targets from
        "ce_max_membrane_loss": [False, False],
        "ce_rate_loss": [True, False],
        "ce_count_loss": [True, False],
        "mse_count_loss": [True, False],
        "ce_latency_loss": [True, False],
        "mse_temporal_loss": [True, False],
        "ce_temporal_loss": [True, False],
    }  # note: when using mse_count_loss, the target spike-count should be
    # for a truncated time, not for the full time

    reg_dict = {"l1_rate_sparsity": True}

    # acc_dict = {
    #     SF.accuracy_rate : [False, False, False, True]
    # }

    time_var_targets = False
    counter = len(criterion_dict)
    for criterion_key in criterion_dict:
        if criterion_key == criterion.__name__:
            loss_spk, time_var_targets = criterion_dict[
                criterion_key
            ]  # m: mem, s: spk // s: every step, e: end
            if time_var_targets:
                time_var_targets = criterion.time_var_targets  # check this
        counter -= 1
    if counter:  # fix the print statement
        raise TypeError(
            "``criterion`` must be one of the loss functions in "
            "``snntorch.functional``: e.g., 'mse_membrane_loss', "
            "'ce_max_membrane_loss', 'ce_rate_loss' etc."
        )

    if regularization:
        for reg_item in reg_dict:
            if reg_item == regularization.__name__:
                # m: mem, s: spk // s: every step, e: end
                reg_spk = reg_dict[reg_item]

    num_return = utils._final_layer_check(net)  # number of outputs

    step_trunc = 0  # ranges from 0 to K, resetting every K time steps
    K_count = 0
    loss_trunc = 0  # reset every K time steps
    loss_avg = 0
    iter_count = 0

    mem_rec_trunc = []
    spk_rec_trunc = []

    #net = net.to(device)

    data_iterator = iter(dataloader)
    for data, targets in data_iterator:
        iter_count += 1
        net.train()
        data = data.to(device)
        targets = targets.to(device)

        utils.reset(net)

        for step in range(num_steps):
            if num_return == 2:
                if time_var:
                    if time_first:
                        spk, mem = net(spike_data[step])
                    else:
                        spk, mem = net(spike_data.transpose(1, 0)[step])
                else:
                    spk, mem = net(data)

            elif num_return == 3:
                if time_var:
                    if time_first:
                        spk, _, mem = net(spike_data[step])
                    else:
                        spk, _, mem = net(spike_data.transpose(1, 0)[step])
                else:
                    spk, _, mem = net(data)

            elif num_return == 4:
                if time_var:
                    if time_first:
                        spk, _, _, mem = net(spike_data[step])
                    else:
                        spk, _, _, mem = net(spike_data.transpose(1, 0)[step])
                else:
                    spk, _, _, mem = net(data)

            # else:  # assume not an snn.Layer returning 1 val
            #     if time_var:
            #         spk = net(data[step])
            #     else:
            #         spk = net(data)
            #     spk_rec.append(spk)

            spk_rec_trunc.append(spk)
            mem_rec_trunc.append(mem)

            step_trunc += 1
            if step_trunc == K:
                # spk_rec += spk_rec_trunc # test
                # mem_rec += mem_rec_trunc # test

                spk_rec_trunc = torch.stack(spk_rec_trunc, dim=0)
                mem_rec_trunc = torch.stack(mem_rec_trunc, dim=0)

                # loss_spk is True if input to criterion is spk;
                # reg_spk is True if input to reg is spk

                # catch case for time_varying_targets?
                if time_var_targets:
                    if loss_spk:
                        loss = criterion(
                            spk_rec_trunc,
                            targets[int(K_count * K) : int((K_count + 1) * K)],
                        )
                    else:
                        loss = criterion(
                            mem_rec_trunc,
                            targets[int(K_count * K) : int((K_count + 1) * K)],
                        )
                else:
                    if loss_spk:
                        loss = criterion(spk_rec_trunc, targets)
                    else:
                        loss = criterion(mem_rec_trunc, targets)

                if regularization:
                    if reg_spk:
                        loss += regularization(spk_rec_trunc)
                    else:
                        loss += regularization(mem_rec_trunc)

                loss_trunc += loss
                loss_avg += loss / (num_steps / K)

                optimizer.zero_grad(set_to_none=True)
                loss_trunc.backward()
                optimizer.step()
                scheduler.step()

                for neuron in neurons_dict:
                    if neuron:
                        neurons_dict[neuron].detach_hidden()
                        # detach_hidden --> _reset_hidden

                K_count += 1
                step_trunc = 0
                loss_trunc = 0
                spk_rec_trunc = []
                mem_rec_trunc = []
                #gc.collect()

        if (step == num_steps - 1) and (num_steps % K):
            spk_rec_trunc = torch.stack(spk_rec_trunc, dim=0)
            mem_rec_trunc = torch.stack(mem_rec_trunc, dim=0)

            if time_var_targets:
                idx1 = K_count * K
                idx2 = K_count * K + num_steps % K
                if loss_spk:
                    loss = criterion(
                        spk_rec_trunc,
                        targets[int(idx1) : int(idx2)],
                    )
                else:
                    loss = criterion(
                        mem_rec_trunc,
                        targets[int(idx1) : int(idx2)],
                    )
            else:
                if loss_spk:
                    loss = criterion(spk_rec_trunc, targets)
                else:
                    loss = criterion(mem_rec_trunc, targets)

            if regularization:
                if reg_spk:
                    loss += regularization(spk_rec_trunc)
                else:
                    loss += regularization(mem_rec_trunc)

            loss_trunc += loss
            loss_avg += loss / int(num_steps % K)

            optimizer.zero_grad(set_to_none=True)
            loss_trunc.backward()
            optimizer.step()
            scheduler.step()

            K_count = 0
            step_trunc = 0
            loss_trunc = 0
            spk_rec_trunc = []
            mem_rec_trunc = []
            #gc.collect()

            for neuron in neurons_dict:
                if neuron:
                    neurons_dict[neuron].detach_hidden() 

    avg_loss = loss_avg / iter_count  # , spk_rec, mem_rec

    print(f"Epoch: {epoch}")
    current_accuracy = test_accuracy(test_loader, net, num_steps, population_code=True, num_classes=10)*100
    if current_accuracy > best_accuracy:
      best_accuracy = current_accuracy
      filename = f"sweep_fs_slp/r2_s{slp}_acc{best_accuracy:.2f}.pth" 
      # Check for existing files with the same slp value
      for file in os.listdir("sweep_fs_slp"):
          if file.startswith(f"r2_s{slp}_") and file.endswith(".pth"):
              # If a file with the same slp exists, delete it
              os.remove(os.path.join("sweep_fs_slp", file))

      # Save the new model
      torch.save(net.state_dict(), filename)
      best_epoch = epoch
    print(f"Slope: {slp}, Curent acc: {current_accuracy:.2f}%, Best acc: {best_accuracy:.2f}% \n")
    if(epoch - best_epoch > 5):
      print("Early stopping")
      break
    
exit()