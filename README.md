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

If you find this code useful in your work, please cite the following source:

```bibtex
@inproceedings{aliyev2024exploring,
  title={Exploring the Sparsity-Quantization Interplay on a Novel Hybrid SNN Event-Driven Architecture},
  author={Aliyev, Ilkin and Lopez, Jesus and Adegbija, Tosiron},
  booktitle={Design, Automation \& Test in Europe Conference \& Exhibition (DATE)},
  year={2025},
  organization={IEEE}
}
```
# Scripts Overview

## Requirements/Dependencies
- **Python 3.11**: (Note: Newer Python versions may not be compatible with some libraries used at the time of testing)
- **PyTorch 2.2.2 with CUDA 12.1**
- **snnTorch 0.7.0**: (Newer versions may not be compatible with this repository)
- **Brevitas 0.10.2**

## Script Summary
- **Training.py**: Main training script.
- **Extract.py**: Extracts weights and biases from pre-trained models for hardware simulation. Also extracts a dataset sample and converts it into a text file for hardware simulation.
- **Net.py**: Defines the model architecture through the `Net` class.
- **Configs.py**: Contains hyperparameters shared across all datasets.
- **Datasets.py**: Defines classes and dataset-specific parameters used during experimentation.
- **Functions.py**: Contains utility functions used in both `Training.py` and `Extract.py`.

## Training
Training is mostly automated, with default values set to match those used during experiments. To train a model on CIFAR10, simply run the script as is. The process will train two models: one non-quantized and one with Int4 quantization. During training, the script saves the weights and biases of the best-performing epoch, organizing them into folders and removing previous epochs. To use a different dataset, modify the dataset class at the beginning of the `Training.py` script.

## Weight and Bias Extraction
In **Extract.py**, follow these steps:
1. Set the model path to point to the saved model weights.
2. Set the dataset to match the one used to train the model.
3. Specify the number of Event Control Units (ECs) used in each layer. EC size must be a factor of the convolution layer's channel size. Valid factors for the layer sizes used in the paper are provided in the comments.
4. Run the script. The script will output a line starting with `` `define ``, followed by the path to a macros file. This line should be copied directly into the hardware's `top_wrapper`.

>[!WARNING]
> For direct-coded models, the EC size for `conv_1_1` should always be set to 1. The dense layer in hybrid hardware is hardcoded to use a single ECU. For rate-coded models, EC size can be any factor of the layer size, similar to other layers.

### Macro File Overview
The macro file includes the following parameters:
- **time_steps**: Defines the number of time steps (used only with rate-encoded models in the corresponding sparse hardware code).
- **model_directory**: Specifies the directory containing the extracted model.
- **ec_sizes**: The EC sizes set in `Extract.py`.
- **w_sfactor**: The weight scale factor to convert INT weights to FP32.
- **b_sfactor**: The bias scale factor to convert INT biases to FP32.
- **w_zpt**: The weight zero point, used to convert INT weights to FP32 (usually 0 in our models).
- **b_zpt**: The bias zero point, used to convert INT biases to FP32 (usually 0 in our models).

# Hardware Overview

## Simulations and Synthesis Tools
- **hybrid_sim**: Simulates direct-coded models (FP32 and INT4) for latency testing.
- **hybrin_synth**: Synthesis tool to calculate energy usage of direct-coded models (FP32 only).
- **hybrin_synth_int**: Synthesis tool to calculate energy usage of direct-coded models (INT4 only).
- **sparse_sim**: Simulates rate-coded models (FP32 and INT4) for latency testing.
- **sparse_synth_int**: Synthesis tool to calculate energy usage of rate-coded models (INT4 only). *No FP32 equivalent, as no FP32 rate-coded models were tested.*

## Latency Testing Workflow
1. Select the appropriate hardware code based on the model and simulation type as described above.
2. Copy the `` `define `` line generated by **Extract.py**.
3. Run the behavioral simulation, which will use the macros file to set the correct parameters.
4. The simulation ends when the `fc_2_spk_RAM_loaded` signal is triggered.
5. Upon completion, the cycle and spike data will be written to a file named `cycles_and_spikes.txt`. The first set of values represents latency in cycles for each layer, followed by the total latency. The second set contains the spike count generated by each layer.

>[!IMPORTANT]  
> Ensure that `-d SIM` is added to the `xsim.compile.xvlog.more_options*` field in the simulation project settings within Vivado. Without this, the simulation will fail.

### Balancing Hardware Utilization
Each layer of the model requires different resources to process its inputs effectively. To maximize efficiency and minimize idle times, adjust EC sizes so that the latencies of each layer are roughly equal.

While perfectly balancing latency may not always be feasible due to EC size constraints (which must be factors of the convolution channel sizes), you can monitor each layer's latency and adjust EC sizes in **Extract.py** to improve the balance. After each adjustment, rerun the simulation and check the latency.

Be aware that some latency (like the base latency of loading spike trains into layers) is unavoidable, as these processes are serial. You can estimate this latency by examining signals like `CONV_X_X_input_spks` (where "X_X" corresponds to specific convolution layers) and `FCX_input_spks_sum`, which tracks the number of spikes input into each layer. The time from when this signal starts increasing to when it stops indicates the base latency. Future iterations may reduce this base latency.
