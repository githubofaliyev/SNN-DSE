import urllib.request
import torch, torch.nn as nn
import snntorch as snn
import brevitas.nn as qnn
from snntorch import utils
from snntorch import surrogate
import torch.nn.functional as F
import snntorch.functional as SF
from snntorch import spikegen

from torch.utils.data import DataLoader
from torchvision import datasets, transforms

from brevitas.quant.scaled_int import Int8BiasPerTensorFloatInternalScaling as Int8Bias
from datetime import datetime

config = {
    "num_epochs": 225,  # Number of epochs to train for (per trial)
    "batch_size": 64,  # Batch size
    "seed": 9000,

    # Quantization
    "num_bits": 4,  # Bit resolution

    # Network parameters
    "grad_clip": False,  # Whether or not to clip gradients
    "weight_clip": False,  # Whether or not to clip weights
    "batch_norm": True,  # Whether or not to use batch normalization
    "dropout": 0.102,  # Dropout rate
    "beta": 0.15,  # Decay rate parameter (beta)
    "threshold": 0.5,  # Threshold parameter (theta)
    "lr": 5.0e-3,  # Initial learning rate
    "slope": 1.0,  # Slope value (k)

    # Fixed params
    "num_steps": 58,  # 58 Number of timesteps to encode input for
    "correct_rate": 1.0,  # Correct rate
    "incorrect_rate": 0.0,  # Incorrect rate
    "betas": (0.9, 0.999),  # Adam optimizer beta values
    "t_0": 4690,  # Initial frequency of the cosine annealing scheduler
    "eta_min": 0,  # Minimum learning rate
    "pop_size": 1000  # population size for population encoding
}
print(config)
data_path = 'C:/Users/jlopezramos/Documents/Deep Learning/datasets/'
device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
print(device)

print('==> Preparing data..')

"""
transform_train = transforms.Compose([
    transforms.RandomCrop(32, padding=4),
    transforms.RandomHorizontalFlip(),
    transforms.ToTensor(),
    transforms.Normalize((0.5071, 0.4867, 0.4408), (0.2675, 0.2565, 0.2761)),
])
transform_test = transforms.Compose([
    transforms.ToTensor(),
    transforms.Normalize((0.5071, 0.4867, 0.4408), (0.2675, 0.2565, 0.2761)),
])

"""
transform_train = transforms.Compose([
    transforms.RandomCrop(32, padding=4),
    transforms.RandomHorizontalFlip(),
    transforms.ToTensor(),
    transforms.Normalize((0.4914, 0.4822, 0.4465), (0.2023, 0.1994, 0.2010)),
])

transform_test = transforms.Compose([
    transforms.ToTensor(),
    transforms.Normalize((0.4914, 0.4822, 0.4465), (0.2023, 0.1994, 0.2010)),
])

#transform = transforms.Compose([
#        transforms.ToTensor(),
#        transforms.Normalize((0.4376821, 0.4437697, 0.47280442), (0.19803012, 0.20101562, 0.19703614))
#    ])

# Download and load the training and test FashionMNIST datasets
#fmnist_train = datasets.SVHN(data_path, split='train', download=True, transform=transform)
#fmnist_test = datasets.SVHN(data_path, split='test', download=True, transform=transform)

fmnist_train = datasets.CIFAR10(root=data_path, train=True, download=True, transform=transform_train)
fmnist_test = datasets.CIFAR10(root=data_path, train=False, download=True, transform=transform_test)

trainloader = DataLoader(fmnist_train, batch_size=config["batch_size"], shuffle=True)
testloader = DataLoader(fmnist_test, batch_size=config["batch_size"], shuffle=False)

class Net(nn.Module):
    def __init__(self, config):
        super().__init__()
        self.num_bits = config["num_bits"]
        self.thr = config["threshold"]
        self.slope = config["slope"]
        self.beta = config["beta"]
        self.num_steps = config["num_steps"]
        self.batch_norm = config["batch_norm"]
        self.p1 = config["dropout"]
        self.spike_grad = surrogate.fast_sigmoid(self.slope)
        self.pop_size = config["pop_size"]

        # Initialize Layers
        #self.conv1 = qnn.QuantConv2d(3, 16, 5, bias=False, weight_bit_width=self.num_bits)
        # VGG9 layer 1
        self.Qconv1_1 = qnn.QuantConv2d(3, 64, 3, weight_bit_width=self.num_bits, bias=True, padding=1, bias_quant=Int8Bias, bias_bit_width=self.num_bits)
        self.lif1 = snn.Leaky(self.beta, threshold=self.thr, spike_grad=self.spike_grad)
        self.Qconv1_2 = qnn.QuantConv2d(64, 112, 3, bias=True, padding=1, weight_bit_width=self.num_bits, bias_quant=Int8Bias, bias_bit_width=self.num_bits)
        self.conv1_bn = nn.BatchNorm2d(112)
        self.lif2 = snn.Leaky(self.beta, threshold=self.thr, spike_grad=self.spike_grad)
        # VGG9 layer 2
        self.conv2_1 = nn.Conv2d(112, 192, 3, bias=True, padding=1)
        self.lif3 = snn.Leaky(self.beta, threshold=self.thr, spike_grad=self.spike_grad)
        self.conv2_2 = nn.Conv2d(192, 216, 3, bias=True, padding=1)
        self.conv2_bn = nn.BatchNorm2d(216)
        self.lif4 = snn.Leaky(self.beta, threshold=self.thr, spike_grad=self.spike_grad)
        # VGG9 layer 3
        self.conv3_1 = nn.Conv2d(216, 480, 3, bias=True, padding=1)
        self.lif5 = snn.Leaky(self.beta, threshold=self.thr, spike_grad=self.spike_grad)
        self.conv3_2 = nn.Conv2d(480, 504, 3, bias=True, padding=1)
        self.lif6 = snn.Leaky(self.beta, threshold=self.thr, spike_grad=self.spike_grad)
        self.conv3_3 = nn.Conv2d(504, 560, 3, bias=True, padding=1)
        self.conv3_bn = nn.BatchNorm2d(560)
        self.lif7 = snn.Leaky(self.beta, threshold=self.thr, spike_grad=self.spike_grad)
        # VGG9 layer 4
        #self.fc1 = qnn.QuantLinear(64 * 5 * 5, 10, bias=False, weight_bit_width=self.num_bits)
        self.fc1 = nn.Linear(560*4*4, 1064)
        self.lif8 = snn.Leaky(self.beta, threshold=self.thr, spike_grad=self.spike_grad)
        self.fc2 = nn.Linear(1064, self.pop_size)
        self.lif9 = snn.Leaky(self.beta, threshold=self.thr, spike_grad=self.spike_grad)
        self.dropout = nn.Dropout(self.p1)

    def forward(self, x):
        # Initialize hidden states and outputs at t=0
        mem1 = self.lif1.init_leaky()
        mem2 = self.lif2.init_leaky()
        mem3 = self.lif3.init_leaky()
        mem4 = self.lif4.init_leaky()
        mem5 = self.lif5.init_leaky()
        mem6 = self.lif6.init_leaky()
        mem7 = self.lif7.init_leaky()
        mem8 = self.lif8.init_leaky()
        mem9 = self.lif9.init_leaky()

        # Record the final layer
        spk3_rec = []
        mem3_rec = []

        # encode input into spikes using rate encoding
        spk_data_rate = spikegen.rate(x, num_steps=self.num_steps)

        # Forward pass
        for step in range(self.num_steps):
            # layer 1
            spk1, mem1 = self.lif1(self.Qconv1_1(spk_data_rate[step]), mem1)
            cur1 = F.max_pool2d(self.Qconv1_2(spk1), 2)
            spk2, mem2 = self.lif2(self.conv1_bn(cur1), mem2)
            # layer 2
            spk3, mem3 = self.lif3(self.conv2_1(spk2), mem3)
            cur2 = F.max_pool2d(self.conv2_2(spk3), 2)
            spk4, mem4 = self.lif4(self.conv2_bn(cur2), mem4)
            # layer 3
            spk5, mem5 = self.lif5(self.conv3_1(spk4), mem5)
            spk6, mem6 = self.lif6(self.conv3_2(spk5), mem6)
            cur3 = F.max_pool2d(self.conv3_3(spk6), 2)
            spk7, mem7 = self.lif7(self.conv3_bn(cur3), mem7)

            cur4 = self.dropout(self.fc1(spk7.flatten(1)))
            spk8, mem8 = self.lif8(cur4, mem8)
            spk9, mem9 = self.lif9(self.fc2(spk8), mem9)
            spk3_rec.append(spk9)
            mem3_rec.append(mem9)

        return torch.stack(spk3_rec, dim=0), torch.stack(mem3_rec, dim=0)

net = Net(config).to(device)

optimizer = torch.optim.Adam(net.parameters(),
    lr=config["lr"], betas=config["betas"]
)
scheduler = torch.optim.lr_scheduler.CosineAnnealingLR(optimizer,
    T_max=config["t_0"],
    eta_min=config["eta_min"],
    last_epoch=-1
)
criterion = SF.mse_count_loss(correct_rate=config["correct_rate"],
    incorrect_rate=config["incorrect_rate"],
    population_code=True, num_classes=10
)

def train(config, net, trainloader, criterion, optimizer, device="cpu", scheduler=None):
    """Complete one epoch of training."""

    net.train()
    loss_accum = []
    lr_accum = []
    i = 0
    for data, labels in trainloader:
        data, labels = data.to(device), labels.to(device)
        spk_rec, _ = net(data)
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
        scheduler.step()
        loss_accum.append(loss.item() / config["num_steps"])
        lr_accum.append(optimizer.param_groups[0]["lr"])

    return loss_accum, lr_accum

def test(config, net, testloader, device="cpu"):
    """Calculate accuracy on full test set."""
    correct = 0
    total = 0
    with torch.no_grad():
        net.eval()
        for data in testloader:
            images, labels = data
            images, labels = images.to(device), labels.to(device)
            outputs, _ = net(images)
            accuracy = SF.accuracy_rate(outputs, labels, population_code=True, num_classes=10)
            total += labels.size(0)
            correct += accuracy * labels.size(0)

    return 100 * correct / total

loss_list = []
lr_list = []
best_accuracy = 0.0
best_epoch = 0
patience = 30

start_date_time_obj = datetime.now()
start_date_time_str = start_date_time_obj.strftime("%m_%d_%Y-%I_%M_%S_%p")

log = open(f"./L1 INT4 S{config['num_steps']} P{config['pop_size']} - {start_date_time_str}.log", 'w')
print(f"=======Training Net =======")
log.write(f"=======Training Net =======\n")
# Train
for epoch in range(config['num_epochs']):
    loss, lr = train(config, net, trainloader, criterion, optimizer,
        device, scheduler
    )
    loss_list = loss_list + loss
    lr_list = lr_list + lr
    # Test
    curr_accuracy = test(config, net, testloader, device)
    if curr_accuracy > best_accuracy:
        best_accuracy = curr_accuracy

        if curr_accuracy > best_accuracy + 0.5:
            best_epoch = epoch

    print(f"Epoch: {epoch} \tCurent acc: {curr_accuracy:.2f}%, Best acc: {best_accuracy:.2f}%,      Elapsed Time: {datetime.now()-start_date_time_obj}\n")
    log.write(f"Epoch: {epoch} \tCurent acc: {curr_accuracy:.2f}%, Best acc: {best_accuracy:.2f}%,      Elapsed Time: {datetime.now()-start_date_time_obj}\n")
    log.flush()
    # if(epoch - best_epoch > patience):
    #   print("Early stopping")
    #   break

log.close()