import torch
from torch import nn
import os

from Configs import *
from Datasets import *
from Functions import *
from Net import Net
from datetime import datetime

from brevitas.quant.scaled_int import Int8BiasPerTensorFloatInternalScaling as Int8Bias
from brevitas.quant.scaled_int import Int8WeightPerTensorFloat as Int8Weight

data_path = "./datasets/"
config = direct_config
dataset = CIFAR10(config, data_path)

for trial in range(1, 3):
    for is_quantized in (False, True):
        if is_quantized:
            weight_quant = Int8Weight
            bias_quant = Int8Bias
        else:
            weight_quant = None
            bias_quant = None

        device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
        print(device)

        print('==> Preparing data..')

        net = Net(config, dataset, weight_quant, bias_quant).to(device)
        old_model_path = ""
        current_model_path = ""
        loss_list = []
        lr_list = []

        start_date_time_obj = datetime.now()
        start_date_time_str = datetime.now().strftime("%m_%d_%Y-%I_%M_%S_%p")

        experiment_name = f'{dataset.name} S{config["num_steps"]} T{trial} '
        if (is_quantized):
            experiment_name += f'INT{config["num_bits"]}'
        else:
            experiment_name += f'FP32'

        models_path = f'./{dataset.name} S{config["num_steps"]} {start_date_time_str}/'
        os.makedirs(models_path, exist_ok=True)
        log = open(f'{models_path}/{experiment_name} Log {start_date_time_str}.log', 'w')
        log.write("Config\n")
        log.write(
            f'num_epochs:{config["num_epochs"]}, batch_size:{config["batch_size"]}, num_steps:{config["num_steps"]}, '
            f'pop_size:{config["pop_size"]}\n\n')

        print(f"=======Training Net=======\n======={experiment_name}======\n")
        log.write(f"=======Training Net=======\n======={experiment_name}======\n")

        # Train
        best_accuracy = 0
        for epoch in range(dataset.num_epochs):
            log.flush()

            loss, lr = train(config, net, dataset, device)
            loss_list = loss_list + loss
            lr_list = lr_list + lr

            # Test
            curr_accuracy = test(config, net, dataset, device)
            if curr_accuracy > best_accuracy:
                old_model_path = current_model_path
                best_accuracy = curr_accuracy

                # Save the new model
                curr_date_time = datetime.now().strftime("%m_%d_%Y-%I_%M_%S_%p")
                model_dir = f"{models_path}/{experiment_name} ({curr_accuracy:0.2f}%) EP{epoch} {curr_date_time}.pth"
                torch.save(net.state_dict(), model_dir)
                current_model_path = model_dir

                # removes old model after saving the best model the program execution is interrupted while it is
                # saving the best model
                if (os.path.isfile(old_model_path)):
                    os.remove(old_model_path)

            print(f"Epoch: {epoch} \tCurrent acc: {curr_accuracy:.2f}%, Best acc: {best_accuracy:.2f}%,      "
                  f"Elapsed Time: {datetime.now() - start_date_time_obj}")
            log.write(f"Epoch: {epoch} \tCurrent acc: {curr_accuracy:.2f}%, Best acc: {best_accuracy:.2f}%,      "
                      f"Elapsed Time: {datetime.now() - start_date_time_obj}")

        log.write(f"Stopping after {config['num_epochs']} Epochs\n")
        log.close()
