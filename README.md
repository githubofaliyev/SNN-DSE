This repository contains a cycle-accurate SystemC Transaction-level Modeling (TLM) formalism (software) and a Vivado hardware implementation of a sparsity-aware spiking neural network (SNN). The network uses leaky integrate-and-fire (LIF) neurons and event-driven computation. The network parameters and input spikes are parsed from files generated by snnTorch. The model is capable of flexibly assigning hardware resources based on workload characteristics of the neural net.

## Publication
The related paper has been accepted in [IEEE JETCAS'23](https://ieeexplore.ieee.org/document/10299654) and is also available on [arXiv](https://arxiv.org/pdf/2310.16745.pdf).
[![Paper](https://img.shields.io/badge/Paper-IEEE%20JETCAS-blue.svg)](https://ieeexplore.ieee.org/document/10299654)
[![arXiv](https://img.shields.io/badge/arXiv-2310.16745-b31b1b.svg)](https://arxiv.org/pdf/2310.16745.pdf)

## Parameters

The software uses some global variables and constants defined in "defines.h". You can modify them according to your needs. Some of them are:

- INPUT_LAYER_SIZE: The number of neurons in the input layer.
- LAYER0_SIZE_LOGICAL: The number of neurons in the first hidden layer.
- LAYER1_SIZE_LOGICAL: The number of neurons in the second hidden layer.
- LAYER2_SIZE_LOGICAL: The number of neurons in the output layer.
- L0_NEURON_UNIT_SIZE: The neuron unit size in the first hidden layer.
- L1_NEURON_UNIT_SIZE: The neuron unit size in the second hidden layer.
- L2_NEURON_UNIT_SIZE: The neuron unit size in the output layer.
- TIME_STEP: The number of time steps for the spike train length.

## Usage
To run the SystemC software, follow these steps:

1. Make sure you have SystemC installed on your system and set the `SYSTEMC` environment variable to point to its installation directory.
2. Run `./custom_run.sh` to execute the shell script that will generate neuron modules, parse data files, compile and run the SNN model.
3. Wait for the simulation to finish and check the output file `trace_log.txt` for the simulation time and output spikes.

Alternatively, you can run each step manually using the commands in `custom_run.sh`.

## License
This code is released under the MIT license. See LICENSE.txt for more details.
