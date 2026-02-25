from snntorch import surrogate, spikegen

import torch, torch.nn as nn
import snntorch as snn
import brevitas.nn as qnn

import torch.nn.functional as F


def get_surrogate(surrogate_type, slope):
    if surrogate_type == "fast_sigmoid":
        return surrogate.fast_sigmoid(slope=slope)
    elif surrogate_type == "atan":
        return surrogate.atan(alpha=slope)
    elif surrogate_type == "spike_rate_escape":
        return surrogate.spike_rate_escape(beta=slope)
    elif surrogate_type == "SSO":
        return surrogate.SSO(mean=0, variance=slope)
    else:
        raise ValueError(f"Unknown surrogate type: {surrogate_type}")


def make_neuron(neuron_type, beta, threshold, spike_grad):
    if neuron_type == "lif":
        return snn.Leaky(beta, threshold=threshold, spike_grad=spike_grad)
    elif neuron_type == "lapicque":
        return snn.Lapicque(beta=beta, threshold=threshold, spike_grad=spike_grad)
    else:
        raise ValueError(f"Unknown neuron type: {neuron_type}")


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
        self.pop_size = dataset.pop_size
        self.is_rate_encoded = dataset.is_rate_encoded
        self.is_event_encoded = getattr(dataset, "is_event_encoded", False)
        self.input_size = getattr(dataset, "input_size", 32)

        surrogate_type = config.get("surrogate_type", "fast_sigmoid")
        neuron_type = config.get("neuron_type", "lif")
        self.neuron_type = neuron_type

        self.spike_grad = get_surrogate(surrogate_type, self.slope)

        in_ch = getattr(dataset, "input_channels", 3)
        spatial = self.input_size // 8  # after 3x MP2

        # VGG9 layer 1
        self.Qconv1_1 = qnn.QuantConv2d(in_ch, 64, 3, padding=1,
                                        weight_quant=weight_quant, weight_bit_width=self.num_bits,
                                        bias=True, bias_quant=bias_quant, bias_bit_width=self.num_bits)
        self.lif1 = make_neuron(neuron_type, self.beta, self.thr, self.spike_grad)
        self.Qconv1_2 = qnn.QuantConv2d(64, 28, 3, padding=1,
                                        weight_quant=weight_quant, weight_bit_width=self.num_bits,
                                        bias=True, bias_quant=bias_quant, bias_bit_width=self.num_bits)
        self.lif2 = make_neuron(neuron_type, self.beta, self.thr, self.spike_grad)
        self.conv1_bn = nn.BatchNorm2d(28)

        # VGG9 layer 2
        self.Qconv2_1 = qnn.QuantConv2d(28, 48, 3, padding=1,
                                        weight_quant=weight_quant, weight_bit_width=self.num_bits,
                                        bias=True, bias_quant=bias_quant, bias_bit_width=self.num_bits)
        self.lif3 = make_neuron(neuron_type, self.beta, self.thr, self.spike_grad)
        self.Qconv2_2 = qnn.QuantConv2d(48, 54, 3, padding=1,
                                        weight_quant=weight_quant, weight_bit_width=self.num_bits,
                                        bias=True, bias_quant=bias_quant, bias_bit_width=self.num_bits)
        self.lif4 = make_neuron(neuron_type, self.beta, self.thr, self.spike_grad)
        self.conv2_bn = nn.BatchNorm2d(54)

        # VGG9 layer 3
        self.Qconv3_1 = qnn.QuantConv2d(54, 120, 3, padding=1,
                                        weight_quant=weight_quant, weight_bit_width=self.num_bits,
                                        bias=True, bias_quant=bias_quant, bias_bit_width=self.num_bits)
        self.lif5 = make_neuron(neuron_type, self.beta, self.thr, self.spike_grad)
        self.Qconv3_2 = qnn.QuantConv2d(120, 126, 3, padding=1,
                                        weight_quant=weight_quant, weight_bit_width=self.num_bits,
                                        bias=True, bias_quant=bias_quant, bias_bit_width=self.num_bits)
        self.lif6 = make_neuron(neuron_type, self.beta, self.thr, self.spike_grad)
        self.Qconv3_3 = qnn.QuantConv2d(126, 140, 3, padding=1,
                                        weight_quant=weight_quant, weight_bit_width=self.num_bits,
                                        bias=True, bias_quant=bias_quant, bias_bit_width=self.num_bits)
        self.lif7 = make_neuron(neuron_type, self.beta, self.thr, self.spike_grad)
        self.conv3_bn = nn.BatchNorm2d(140)

        # FC layers
        self.Qfc1 = qnn.QuantLinear(140 * spatial * spatial, 1064,
                                    weight_quant=weight_quant, weight_bit_width=self.num_bits,
                                    bias=True, bias_quant=bias_quant, bias_bit_width=self.num_bits)
        self.lif8 = make_neuron(neuron_type, self.beta, self.thr, self.spike_grad)
        self.Qfc2 = qnn.QuantLinear(1064, self.pop_size,
                                    weight_quant=weight_quant, weight_bit_width=self.num_bits,
                                    bias=True, bias_quant=bias_quant, bias_bit_width=self.num_bits)
        self.lif9 = make_neuron(neuron_type, self.beta, self.thr, self.spike_grad)
        self.dropout = nn.Dropout(self.p1)

    def _init_mem(self, lif):
        if self.neuron_type == "lapicque":
            return lif.init_lapicque()
        return lif.init_leaky()

    def forward(self, x):
        mem1 = self._init_mem(self.lif1)
        mem2 = self._init_mem(self.lif2)
        mem3 = self._init_mem(self.lif3)
        mem4 = self._init_mem(self.lif4)
        mem5 = self._init_mem(self.lif5)
        mem6 = self._init_mem(self.lif6)
        mem7 = self._init_mem(self.lif7)
        mem8 = self._init_mem(self.lif8)
        mem9 = self._init_mem(self.lif9)

        spk9_rec = []
        mem9_rec = []

        if self.is_event_encoded:
            # x is (batch, T, C, H, W) from DVS datasets
            sample = x.permute(1, 0, 2, 3, 4)
            # Resize spatial dims to self.input_size if needed
            if sample.shape[-1] != self.input_size or sample.shape[-2] != self.input_size:
                T, B, C, H, W = sample.shape
                sample = sample.reshape(T * B, C, H, W)
                sample = F.interpolate(sample, size=self.input_size, mode='bilinear', align_corners=False)
                sample = sample.reshape(T, B, C, self.input_size, self.input_size)
        elif self.is_rate_encoded:
            sample = spikegen.rate(x, num_steps=self.num_steps)
        else:
            sample = x.expand(self.num_steps, -1, -1, -1, -1)

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
