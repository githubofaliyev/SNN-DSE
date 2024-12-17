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

Corresponding paper is available on Arxiv [![arXiv](https://img.shields.io/badge/https://arxiv.org/pdf/2411.15409.svg)](https://arxiv.org/pdf/2411.15409). 
If you find this code useful in your work, please cite the following source:


```bibtex
@article{aliyev2024exploring,
  title={Exploring the Sparsity-Quantization Interplay on a Novel Hybrid SNN Event-Driven Architecture},
  author={Aliyev, Ilkin and Lopez, Jesus and Adegbija, Tosiron},
  journal={arXiv preprint arXiv:2411.15409},
  year={2024}
}
```
# Scripts
## Requirements/Dependencies
- `Python 3.11` (Newer versions were not compatible with some libraries used at the time of testing)
- `PyTorch 2.2.2 with CUDA 12.1`
- `snnTorch 0.7.0` (Newer versions may be incompatible with this repo)
- `Brevitas 0.10.2`

## Overview
- `Training.py` Main training script
- `Extract.py` Extracts weights and biases from pre-trained models for use in hardware simulation. It also extracts the a sample from the dataset and converts it to a txt file to use in hardware simulation.
- `Net.py` Net class definition
- `Configs.py` Defines hyperparameters used across all datasets
- `Datasets.py` Defines classes for the datasets used. They include dataset specific parameters used for to conduct the experiments
- `Functions.py` Defines functions used in `Training.py` and `Extract.py`

## Training
Training is mostly automated and the default values are set to the values used to run the experiments. To train using CIFAR10, just run the script as is. The scripts will train 2 sets of one non-quantized model and one of an Int4 quantized model. 
As it runs through the epochs it will save the weights and biases of the best epoch in an organized folder structure and delete the previous epoch. To change the dataset to be trained just change the dataset class near the top of `Training.py`.

## Weight+Bias Extraction
In `Extract.py`
1. Set the model path to the path of saved model weights
2. Set the dataset to the same dataset the saved model was trained with
3. Set the amount of Event Control Units(ECs) used in each layer. Must be a factor of the conv layer channel size. Factors of the layer sizes used in the paper are in the comments

> [!WARNING]
> The EC size for conv_1_1 should always be set to 1 with direct coded models. The dense layer in the hybrid hardware is hardcoded to use one ECU.
> For rate coded models, the EC size can be set to any factor of the layer size like the other layers.
   
   
4. Run the script. It tests the accuracy as a sanity check. At the end it will print a line that start with "`define" and is followed by that path to a macros file. This line will be copied directly into the top_wrapper of the hardware.

#### Macro File Overview
The macro file defines the following parameters.
- time_steps: Sets the value of the time_steps. *Used only with rate_encoded encoded models in corresponding sparse hardware code.*
- model_directory: The directory of the folder that contains the extracted model.
- ec_sizes: The ec sizes set in `Extract.py`.
- w_sfactor: The weight scale factor used to convert the INT weights to FP32.
- b_sfactor: The bias scale factor used to conver the INT biases to FP32.
- w_zpt: The weight zero point used to convert the INT weights to FP32. This was always ended up being 0 in our models.
- b_zpt: The bias zero point used to convert the INT biases to FP32. This was always ended up being 0 in our models.

# Hardware
## Overview
- `hybrid_sim` Used to run simulations on direct coded models(FP32 and INT4) for latency testing.
- `hybrin_synth` Used for synthesis to determine energy usage on direct coded models(FP32 Only).
- `hybrin_synth_int` Used for synthesis to determine energy usage of direct coded models(INT4 Only).
- `sparse_sim` Used to run simulations on rate coded models(FP32 and INT4) for latency testing.
- `sparse_synth_int` Use for synhtesis to determine energy usage of rate coded models(INT4 Only). _There is no FP32 equivalent as no FP32 rate coded model was tested._

## Latency Testing
1. Determine the right hardware code to use based on the model and the overview above.
2. Copy the "\`define" line printed by `Extract.py`.
3. Run behavorial simulation. The macros file sets the correct parameters.
4. The simulation is done when the `fc_2_spk_RAM_loaded` signal goes high.
5. Upon completetion the cycles and spikes will be written to a file named `cycles and spikes.txt`. The first group of numbers are the latency of each layer in cycles, followed by the total latency. The second group of numbers are the spikes generated by each layer should you want that info.

### Balancing Hardware Utilization
Each layer demands different resources to process its inputs effectively. To minimize idle times and maximize efficiency, adjust EC sizes so that each layer has approximately equal latency.

Perfectly balancing latency may not be feasible due to restrictions requiring EC sizes to be factors of the convolution channel size. Monitor each layer's latency, adjust EC values in `Extract.py`, and rerun simulations until latencies are roughly equivalent.

Note that each layer has a base latency that cannot be reduced; loading spike trains into layers is a serial process unaffected by EC size. To determine this process's latency, observe signals named `CONV_X_X_input_spks`, where "X_X" corresponds to specific convolution layers; this indicates how many spikes are input into each layer. The duration between when this signal begins increasing and when it stops indicates process latency. Future iterations should be able to reduce this base latency.

## License
This code is released under the MIT license. See LICENSE.txt for more details.
