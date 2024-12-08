This repository contains the implementation of a novel hybrid inference architecture for direct-coded Spiking Neural Networks (SNNs). We address the challenges in efficient input encoding for SNNs and propose a hardware architecture that combines dense and sparse processing cores to maximize inference accuracy and energy.
## Key Features
- Hybrid Architecture: Dense core for input layer processing and sparse cores for event-driven spiking convolutions
- Quantization Analysis: Investigation of quantization effects on network sparsity
- FPGA Implementation: Implemented on Xilinx Virtex UltraScale+ FPGA
- Key performance indicators:
  - Up to 3.4× energy improvement with quantization
  - 10% accuracy improvement and 26.4× less energy consumption per image over rate coding

<table style="width: 75%;">
  <tr>
    <td style="width: 50%;"><img src="https://github.com/user-attachments/assets/c742bb29-5308-46f4-926c-755744689190" alt="c100" style="width: 75%;"/></td>
    <td style="width: 50%;"><img src="https://github.com/user-attachments/assets/eba5b992-1937-4a19-b70a-177ca4dd3b10" alt="c100" style="width: 75%;"/></td>
  </tr>
</table>

Corresponding paper is available on Arxiv [![arXiv](https://img.shields.io/badge/arXiv-2310.16745-b31b1b.svg)](https://arxiv.org/pdf/2411.15409). 
If you find this code useful in your work, please cite the following source:


```bibtex
@article{aliyev2024sparsity,
  title={Sparsity-Aware Hardware-Software Co-Design of Spiking Neural Networks: An Overview},
  author={Aliyev, Ilkin and Svoboda, Kama and Adegbija, Tosiron and Fellous, Jean-Marc},
  journal={arXiv preprint arXiv:2408.14437},
  year={2024}
}
```
# Scripts
## Requirements/Dependencies
- `Python 3.11` (Newer versions were not compatible)
- `PyTorch 2.2.2 with CUDA 12.1`
- `snnTorch 0.7.0` (Newer versions may be incompatible with these repo)

## Overview
- `Training.py` Main training script
- `Extract.py` Extracts weights and biases from pre-trained models for use in hardware simulation
- `Net.py` Net class definition
- `Configs.py` Defines hyperparameters used across all datasets
- `Datasets.py` Defines classes for the datasets used. They include dataset specific parameters used for to conduct the experiments
- `Functions.py` Defines functions used in `Training.py` and `Extract.py`

## Training
Training is mostly automated and the default values are set to the values used to run the experiments. To train using CIFAR10, just run the script as is. The scripts will train 2 sets of one non-quantized model and one of an Int4 quantized model. As it runs through the epochs it will save the weights and biases of the best epoch in an organized folder structure and delete the previous epoch. To change the dataset to be trained just change the dataset class near the top of `Training.py`.

## Weight+Bias Extraction
In `Extract.py`
1. Set the model path to the path of saved model weights
2. Set the dataset to the same dataset the saved model was trained with
3. Set the amount of Event Control Units(ECs) used in each layer. Must be a factor of the conv layer size. Factors of the layer sizes used in the paper are in the comments

> [!WARNING]
> The EC size for conv_1_1 should always be set to 1 with direct coded models. The dense layer in the hybrid hardware is hardcoded to use one ECU.
> For rate coded models, the EC size can be set to any factor of the layer size like the other layers.
   
   
4. Run script.


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
