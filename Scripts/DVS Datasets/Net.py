import torch
import torch.nn as nn
import snntorch as snn
import brevitas.nn as qnn
from snntorch import surrogate, spikegen
import torch.nn.functional as F
import snntorch.functional as SF
import numpy as np

from brevitas.quant.scaled_int import Int8BiasPerTensorFloatInternalScaling as Int8Bias
from brevitas.quant.scaled_int import Int8WeightPerTensorFloat as Int8Weight

class Net(nn.Module):
    def __init__(self, config, dataset, is_quantized, neuron_type=0, optuna_trial=None):
        super().__init__()
        
        self.neuron_type = neuron_type
        if self.neuron_type == 0:
            neuron_class = snn.Leaky
        elif self.neuron_type == 1:
            neuron_class = snn.Lapicque
        else:
            print("Invalid neuron type")
            exit(-7)

        if is_quantized:
            weight_quant = Int8Weight
            bias_quant = Int8Bias
        else:
            weight_quant = None
            bias_quant = None

        self.num_bits = config["num_bits"]
        self.slope = config["slope"]
        self.batch_norm = config["batch_norm"]
        self.p1 = config["dropout"]
        self.spike_grad = surrogate.fast_sigmoid(self.slope)
        self.thr = config["threshold"]
        self.beta = config["beta"]

        self.conv_scaler = config["conv_scaler"]
        self.pop_size_factor = config["pop_size_factor"]
        self.MP1 = config["MP1"]
        self.MP2 = config["MP2"]
        self.MP3 = config["MP3"]

        # Initialize Layers
        # VGG9 layer 1
        self.Qconv1_1 = qnn.QuantConv2d(2, 64, 3, padding=1,
                                        weight_quant=weight_quant, weight_bit_width=self.num_bits,
                                        bias=True, bias_quant=bias_quant, bias_bit_width=self.num_bits)
        self.lif1 = neuron_class(self.beta, threshold=self.thr, spike_grad=self.spike_grad)
        self.Qconv1_2 = qnn.QuantConv2d(64, int(112 * self.conv_scaler), 3, padding=1,
                                        weight_quant=weight_quant, weight_bit_width=self.num_bits,
                                        bias=True, bias_quant=bias_quant, bias_bit_width=self.num_bits)
        self.lif2 = neuron_class(self.beta, threshold=self.thr, spike_grad=self.spike_grad)
        self.conv1_bn = nn.BatchNorm2d(int(112 * self.conv_scaler))

        # VGG9 layer 2
        self.Qconv2_1 = qnn.QuantConv2d(int(112 * self.conv_scaler), int(192 * self.conv_scaler), 3, padding=1,
                                        weight_quant=weight_quant, weight_bit_width=self.num_bits,
                                        bias=True, bias_quant=bias_quant, bias_bit_width=self.num_bits)
        self.lif3 = neuron_class(self.beta, threshold=self.thr, spike_grad=self.spike_grad)
        self.Qconv2_2 = qnn.QuantConv2d(int(192 * self.conv_scaler), int(216 * self.conv_scaler), 3, padding=1,
                                        weight_quant=weight_quant, weight_bit_width=self.num_bits,
                                        bias=True, bias_quant=bias_quant, bias_bit_width=self.num_bits)
        self.lif4 = neuron_class(self.beta, threshold=self.thr, spike_grad=self.spike_grad)
        self.conv2_bn = nn.BatchNorm2d(int(216 * self.conv_scaler))

        # VGG9 layer 3
        self.Qconv3_1 = qnn.QuantConv2d(int(216 * self.conv_scaler), int(480 * self.conv_scaler), 3, padding=1,
                                        weight_quant=weight_quant, weight_bit_width=self.num_bits,
                                        bias=True, bias_quant=bias_quant, bias_bit_width=self.num_bits)
        self.lif5 = neuron_class(self.beta, threshold=self.thr, spike_grad=self.spike_grad)
        self.Qconv3_2 = qnn.QuantConv2d(int(480 * self.conv_scaler), int(504 * self.conv_scaler), 3, padding=1,
                                        weight_quant=weight_quant, weight_bit_width=self.num_bits,
                                        bias=True, bias_quant=bias_quant, bias_bit_width=self.num_bits)
        self.lif6 = neuron_class(self.beta, threshold=self.thr, spike_grad=self.spike_grad)
        self.Qconv3_3 = qnn.QuantConv2d(int(504 * self.conv_scaler), int(560 * self.conv_scaler), 3, padding=1,
                                        weight_quant=weight_quant, weight_bit_width=self.num_bits,
                                        bias=True, bias_quant=bias_quant, bias_bit_width=self.num_bits)
        self.lif7 = neuron_class(self.beta, threshold=self.thr, spike_grad=self.spike_grad)
        self.conv3_bn = nn.BatchNorm2d(int(560 * self.conv_scaler))

        # VGG9 layer 4
        self.Qfc1 = qnn.QuantLinear(int(560 * self.conv_scaler) * (
                    round(dataset.input_sensor_size[0] / 16) * round(dataset.input_sensor_size[1] / 16)),
                                    1064, weight_quant=weight_quant, weight_bit_width=self.num_bits,
                                    bias=True, bias_quant=bias_quant, bias_bit_width=self.num_bits)
        self.lif8 = neuron_class(self.beta, threshold=self.thr, spike_grad=self.spike_grad)
        self.Qfc2 = qnn.QuantLinear(1064, self.pop_size_factor * dataset.num_classes,
                                    weight_quant=weight_quant, weight_bit_width=self.num_bits,
                                    bias=True, bias_quant=bias_quant, bias_bit_width=self.num_bits)
        self.lif9 = neuron_class(self.beta, threshold=self.thr, spike_grad=self.spike_grad)
        self.dropout = nn.Dropout(self.p1)

    def forward(self, x, spk_record=False):
        # Initialize hidden states and outputs at t=0
        # init_leaky() works with lapicque neurons as well since init_lapicque() just calls init_leaky()
        mem1 = self.lif1.init_leaky()
        mem2 = self.lif2.init_leaky()
        mem3 = self.lif3.init_leaky()
        mem4 = self.lif4.init_leaky()
        mem5 = self.lif5.init_leaky()
        mem6 = self.lif6.init_leaky()
        mem7 = self.lif7.init_leaky()
        mem8 = self.lif8.init_leaky()
        mem9 = self.lif9.init_leaky()


        time_steps = x.size(0)

        # Record the layers
        spk1_rec = []
        spk2_rec = []
        spk3_rec = []
        spk4_rec = []
        spk5_rec = []
        spk6_rec = []
        spk7_rec = []
        spk8_rec = []
        spk9_rec = []
        mem9_rec = []

        # Forward pass
        for step in range(time_steps):
            # layer 1
            spk1, mem1 = self.lif1(self.Qconv1_1(x[step]), mem1)
            cur1 = self.conv1_bn(self.Qconv1_2(spk1))
            spk2, mem2 = self.lif2(cur1, mem2)
            MP_spk1 = F.max_pool2d(spk2, self.MP1)
            # layer 2
            spk3, mem3 = self.lif3(self.Qconv2_1(MP_spk1), mem3)
            cur3 = self.conv2_bn(self.Qconv2_2(spk3))
            spk4, mem4 = self.lif4(cur3, mem4)
            MP_spk2 = F.max_pool2d(spk4, self.MP2)
            # layer 3
            spk5, mem5 = self.lif5(self.Qconv3_1(MP_spk2), mem5)
            spk6, mem6 = self.lif6(self.Qconv3_2(spk5), mem6)
            cur5 = self.conv3_bn(self.Qconv3_3(spk6))
            spk7, mem7 = self.lif7(cur5, mem7)
            MP_spk3 = F.max_pool2d(spk7, self.MP3)

            cur7 = self.dropout(self.Qfc1(MP_spk3.flatten(1)))
            spk8, mem8 = self.lif8(cur7, mem8)
            spk9, mem9 = self.lif9(self.Qfc2(spk8), mem9)
            spk9_rec.append(spk9)
            mem9_rec.append(mem9)

            if spk_record:
                spk1_rec.append(spk1)
                spk2_rec.append(MP_spk1)
                spk3_rec.append(spk3)
                spk4_rec.append(MP_spk2)
                spk5_rec.append(spk5)
                spk6_rec.append(spk6)
                spk7_rec.append(MP_spk3)
                spk8_rec.append(spk8)

            spk9_rec.append(spk9)
            mem9_rec.append(mem9)

        spk_rec_layers = [spk1_rec, spk2_rec, spk3_rec, spk4_rec, spk5_rec, spk6_rec, spk7_rec, spk8_rec, spk9_rec]
        return torch.stack(spk9_rec, dim=0), time_steps, spk_rec_layers
