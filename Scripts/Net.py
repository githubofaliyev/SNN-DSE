from snntorch import surrogate, spikegen

import torch, torch.nn as nn
import snntorch as snn
import brevitas.nn as qnn

import torch.nn.functional as F

class Net(nn.Module):
    def __init__(self, config, dataset, weight_quant=None, bias_quant=None):
        super().__init__()
        self.num_bits = config["num_bits"]
        self.thr = config["threshold"]
        self.slope = config["slope"]
        self.beta = config["beta"]
        self.num_steps = dataset.num_steps
        self.batch_norm = config["batch_norm"]
        self.p1 = config["dropout"]
        self.spike_grad = surrogate.fast_sigmoid(self.slope)
        self.pop_size = dataset.pop_size

        # Initialize Layers
        # VGG9 layer 1
        self.Qconv1_1 = qnn.QuantConv2d(3, 64, 3, padding=1,
                                        weight_quant=weight_quant, weight_bit_width=self.num_bits,
                                        bias=True, bias_quant=bias_quant, bias_bit_width=self.num_bits)
        self.lif1 = snn.Leaky(self.beta, threshold=self.thr, spike_grad=self.spike_grad)
        self.Qconv1_2 = qnn.QuantConv2d(64, 112, 3, padding=1,
                                        weight_quant=weight_quant, weight_bit_width=self.num_bits,
                                        bias=True, bias_quant=bias_quant, bias_bit_width=self.num_bits)
        self.lif2 = snn.Leaky(self.beta, threshold=self.thr, spike_grad=self.spike_grad)
        self.conv1_bn = nn.BatchNorm2d(112)

        # VGG9 layer 2
        self.Qconv2_1 = qnn.QuantConv2d(112, 192, 3, padding=1,
                                        weight_quant=weight_quant, weight_bit_width=self.num_bits,
                                        bias=True, bias_quant=bias_quant, bias_bit_width=self.num_bits)
        self.lif3 = snn.Leaky(self.beta, threshold=self.thr, spike_grad=self.spike_grad)
        self.Qconv2_2 = qnn.QuantConv2d(192, 216, 3, padding=1,
                                        weight_quant=weight_quant, weight_bit_width=self.num_bits,
                                        bias=True, bias_quant=bias_quant, bias_bit_width=self.num_bits)
        self.lif4 = snn.Leaky(self.beta, threshold=self.thr, spike_grad=self.spike_grad)
        self.conv2_bn = nn.BatchNorm2d(216)

        # VGG9 layer 3
        self.Qconv3_1 = qnn.QuantConv2d(216, 480, 3, padding=1,
                                        weight_quant=weight_quant, weight_bit_width=self.num_bits,
                                        bias=True, bias_quant=bias_quant, bias_bit_width=self.num_bits)
        self.lif5 = snn.Leaky(self.beta, threshold=self.thr, spike_grad=self.spike_grad)
        self.Qconv3_2 = qnn.QuantConv2d(480, 504, 3, padding=1,
                                        weight_quant=weight_quant, weight_bit_width=self.num_bits,
                                        bias=True, bias_quant=bias_quant, bias_bit_width=self.num_bits)
        self.lif6 = snn.Leaky(self.beta, threshold=self.thr, spike_grad=self.spike_grad)
        self.Qconv3_3 = qnn.QuantConv2d(504, 560, 3, padding=1,
                                        weight_quant=weight_quant, weight_bit_width=self.num_bits,
                                        bias=True, bias_quant=bias_quant, bias_bit_width=self.num_bits)
        self.lif7 = snn.Leaky(self.beta, threshold=self.thr, spike_grad=self.spike_grad)
        self.conv3_bn = nn.BatchNorm2d(560)

        # VGG9 layer 4
        self.Qfc1 = qnn.QuantLinear(560 * 4 * 4, 1064,
                                    weight_quant=weight_quant, weight_bit_width=self.num_bits,
                                    bias=True, bias_quant=bias_quant, bias_bit_width=self.num_bits)
        self.lif8 = snn.Leaky(self.beta, threshold=self.thr, spike_grad=self.spike_grad)
        self.Qfc2 = qnn.QuantLinear(1064, self.pop_size,
                                    weight_quant=weight_quant, weight_bit_width=self.num_bits,
                                    bias=True, bias_quant=bias_quant, bias_bit_width=self.num_bits)
        self.lif9 = snn.Leaky(self.beta, threshold=self.thr, spike_grad=self.spike_grad)
        self.dropout = nn.Dropout(self.p1)

    def forward(self, x, is_rate_encoded=False):
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
        spk9_rec = []
        mem9_rec = []

        if is_rate_encoded is False:
            # expand tensor, duplicating data across a single dimension for direct encoding
            sample = x.expand(self.num_steps, -1, -1, -1, -1)
        else:
            # encode input into spikes using rate encoding
            sample = spikegen.rate(x, num_steps=self.num_steps)

        # Forward pass
        for step in range(self.num_steps):
            # layer 1
            spk1, mem1 = self.lif1(self.Qconv1_1(sample[step]), mem1)
            cur1 = self.conv1_bn(self.Qconv1_2(spk1))
            spk2, mem2 = self.lif2(cur1, mem2)
            MP_spk1 = F.max_pool2d(spk2, 2)
            # layer 2
            spk3, mem3 = self.lif3(self.Qconv2_1(MP_spk1), mem3)
            cur3 = self.conv2_bn(self.Qconv2_2(spk3))
            spk4, mem4 = self.lif4(cur3, mem4)
            MP_spk2 = F.max_pool2d(spk4, 2)
            # layer 3
            spk5, mem5 = self.lif5(self.Qconv3_1(MP_spk2), mem5)
            spk6, mem6 = self.lif6(self.Qconv3_2(spk5), mem6)
            cur5 = self.conv3_bn(self.Qconv3_3(spk6))
            spk7, mem7 = self.lif7(cur5, mem7)
            MP_spk3 = F.max_pool2d(spk7, 2)

            cur7 = self.dropout(self.Qfc1(MP_spk3.flatten(1)))
            spk8, mem8 = self.lif8(cur7, mem8)
            spk9, mem9 = self.lif9(self.Qfc2(spk8), mem9)
            spk9_rec.append(spk9)
            mem9_rec.append(mem9)

        return torch.stack(spk9_rec, dim=0), torch.stack(mem9_rec, dim=0)