import torch, torch.nn as nn
import snntorch as snn
from snntorch import surrogate
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

batch_size = 32
num_steps = 18
data_path='/Users/ilkinaliyev/Desktop/snntorch_main/workspace/datasets'
training_transform_not_augmented = transforms.Compose([
        transforms.ToTensor(),
        transforms.Normalize((0.4376821, 0.4437697, 0.47280442), (0.19803012, 0.20101562, 0.19703614))
    ])

fmnist_train = datasets.SVHN(data_path, split='train', download=True, transform=training_transform_not_augmented)
fmnist_test = datasets.SVHN(data_path, split='test', download=True, transform=training_transform_not_augmented)
train_loader = DataLoader(fmnist_train, batch_size=batch_size, shuffle=True)
test_loader = DataLoader(fmnist_test, batch_size=batch_size, shuffle=True)

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

slp = 8.0
pattern = 'sweep_fs_slp/r2_s{}_acc*.pth'.format(slp)
files = glob.glob(pattern)

if files:
    model_path = files[0]  # Takes the first matching file
    print("Found model:", model_path)
else:
    print("No files found for pattern:", pattern)

device = torch.device("mps" if torch.backends.mps.is_available() else "cpu")

beta = 0.25  # neuron decay rate
#grad = surrogate.atan()
grad = surrogate.fast_sigmoid(slope=1.0)
pop_outputs = 450

net = nn.Sequential(nn.Conv2d(3, 32, 3),
                    nn.MaxPool2d(2),
                    snn.Leaky(beta=beta, spike_grad=grad, init_hidden=True),
                    nn.Conv2d(32, 32, 3),
                    nn.MaxPool2d(2),
                    snn.Leaky(beta=beta, spike_grad=grad, init_hidden=True),
                    nn.Flatten(),
                    nn.Linear(32*6*6, 256),
                    snn.Leaky(beta=beta, spike_grad=grad, init_hidden=True),
                    nn.Linear(256, pop_outputs),
                    snn.Leaky(beta=beta, spike_grad=grad, init_hidden=True, output=True)
                    ).to(device)

if(os.path.exists(model_path)):
    net.load_state_dict(torch.load(model_path))
    print("Model loaded successfully")
else:
    print("Model not found")
net.eval()
current_accuracy = test_accuracy(test_loader, net, num_steps, population_code=True, num_classes=10)*100
print(f"Curent acc: {current_accuracy}% \n")
    
######################## Utility Funcs ########################
def parse_lin(lin):
    result_row = ''.join(map(str, map(int, lin)))
    return result_row

def save_weights_and_biases(conv_layer, dir_name, l, n):
    weights = conv_layer.weight.data
    biases = conv_layer.bias.data

    # Create a dictionary to store weights and biases for each file
    file_data = {i: [] for i in range(n)}

    for i, (filter_tensor, bias) in enumerate(zip(weights, biases)):
        file_index = i % n  # This will ensure the desired distribution

        current_weights = filter_tensor.cpu().numpy().flatten()[::-1].tolist()
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


######################## model dir ########################
l1 = 32
l2 = 32
l3 = 8
l4 = 8
dir_name = 'hw_run/fs/a{}_{}_{}_{}_{}'.format(slp, l1, l2, l3, l4)
os.makedirs(dir_name, exist_ok=True)
fc_dir = 'weights'
full_path_fc = os.path.join(dir_name, fc_dir)  # Corrected path for the 'fc' subdirectory
if os.path.exists(full_path_fc):
    shutil.rmtree(full_path_fc)
os.makedirs(full_path_fc, exist_ok=True)
print_net = os.path.join(dir_name, 'net.txt')
with open(print_net, 'w') as file:
    file.write(str(net))
    #file.write(dataset_name)

######################### spikes. ########################
full_path = os.path.join(dir_name, 'spk_in.txt')
spk_in_data = open(full_path, "w")
torch.manual_seed(1159988220)

d_it, _ = next(iter(test_loader))
second_sample = d_it[0]  # Indexing starts from 0, so 1 indicates the second sample
smpl = spikegen.rate(second_sample.unsqueeze(0), num_steps=num_steps)
#smpl = spikegen.rate(d_it, num_steps=num_steps)[:, 0, 0]
fltnd = smpl.reshape((3*num_steps, 32 * 32))
# Iterate through the first 5 rows of fltnd
for i, lin in enumerate(fltnd[:15]):
    # Convert the tensor to a numpy array if it isn't already
    lin_np = lin.cpu().numpy()
    count_ones = np.sum(lin_np == 1)
    print(f"Number of 1s in row {i+1}: {count_ones}")

for lin in fltnd:
    result_row = parse_lin(lin.cpu().numpy())
    spk_in_data.write(result_row + '\n')


######################### conv ########################
conv1 = net[0]
conv2 = net[3]
#conv3 = net[5]

save_weights_and_biases(conv1, full_path_fc, 1, l1)
save_weights_and_biases(conv2, full_path_fc, 2, l2)

NEURAL_SIZE_1 = int(256/l3)
layer_no = 7

for i in range(0, len(net[layer_no].weight), NEURAL_SIZE_1):
    with open(os.path.join(full_path_fc, f'fc1_nc{i//NEURAL_SIZE_1}.txt'), 'w') as file:
        for j in range(i, min(i + NEURAL_SIZE_1, len(net[layer_no].weight))): # Up to NEURAL_SIZE neurons in this file
            weights = net[layer_no].weight[j].data.cpu().numpy()
            bias = net[layer_no].bias[j].data.cpu().numpy()

            # Write the floating-point numbers for the weights
            file.write('\n'.join(map(str, weights)))

            # Write the bias
            file.write(f'\n{bias}\n')
            
NEURAL_SIZE_2 = int(pop_outputs/l4)
layer_no = 9

for i in range(0, len(net[layer_no].weight), NEURAL_SIZE_2):
    with open(os.path.join(full_path_fc, f'fc2_nc{i//NEURAL_SIZE_2}.txt'), 'w') as file:
        for j in range(i, min(i + NEURAL_SIZE_2, len(net[layer_no].weight))): # Up to NEURAL_SIZE neurons in this file
            weights = net[layer_no].weight[j].data.cpu().numpy()
            bias = net[layer_no].bias[j].data.cpu().numpy()

            # Write the floating-point numbers for the weights
            file.write('\n'.join(map(str, weights)))

            # Write the bias
            file.write(f'\n{bias}\n')            