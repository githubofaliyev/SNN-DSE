This repository contains the corresponding code from the paper.

This repository contains the implementation of a novel hybrid inference architecture for direct-coded Spiking Neural Networks (SNNs). Our work addresses the challenges in efficient input encoding for SNNs and proposes a hardware architecture that combines dense and sparse processing cores to maximize performance and energy efficiency.
## Key Features
- Hybrid Architecture: Dense core for input layer processing and sparse cores for event-driven spiking convolutions
- Quantization Analysis: Investigation of quantization effects on network sparsity
- FPGA Implementation: Implemented on Xilinx Virtex UltraScale+ FPGA

<table style="width: 75%;">
  <tr>
    <td style="width: 50%;"><img src="https://github.com/user-attachments/assets/239feb16-35c7-418e-88e6-704810955b42" alt="c100" style="width: 75%;"/></td>
    <td style="width: 50%;"><img src="https://github.com/user-attachments/assets/9793d8e7-8a16-495f-b1fa-493ff603e3c3" alt="svhn" style="width: 75%;"/></td>
  </tr>
</table>


<div style="text-align: center;">
  <img src="https://github.com/user-attachments/assets/eba5b992-1937-4a19-b70a-177ca4dd3b10" alt="image" style="width: 75%;"/>
</div>


If you find this code useful in your work, please cite the following source:


```bibtex
@article{aliyev2024sparsity,
  title={Sparsity-Aware Hardware-Software Co-Design of Spiking Neural Networks: An Overview},
  author={Aliyev, Ilkin and Svoboda, Kama and Adegbija, Tosiron and Fellous, Jean-Marc},
  journal={arXiv preprint arXiv:2408.14437},
  year={2024}
}
```

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
