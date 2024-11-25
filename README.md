This repository contains the corresponding code from the paper.

The paper presents implementation details for so-called hybrid hardware architecture for direct-coded SNNs -- essentially combining ANN and SNN layers in a single network. The architecture, in turn, enables SNN gain 

![c100 (1)](https://github.com/user-attachments/assets/4a998645-f604-4660-adc4-107f9b17bbf8)


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
