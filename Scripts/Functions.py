import torch, torch.nn as nn
import snntorch.functional as SF
import os


def train(config, net, dataset, device="cpu"):
    trainloader = dataset.GetTrainLoader()

    optimizer = torch.optim.Adam(net.parameters(),
                                 lr=config["lr"], betas=config["betas"]
                                 )
    scheduler = torch.optim.lr_scheduler.CosineAnnealingLR(optimizer,
                                                           T_max=config["t_0"],
                                                           eta_min=config["eta_min"],
                                                           last_epoch=-1
                                                           )
    criterion = SF.mse_count_loss(correct_rate=config["correct_rate"],
                                  incorrect_rate=config["incorrect_rate"],
                                  population_code=True, num_classes=dataset.num_classes
                                  )

    net.train()
    loss_accum = []
    lr_accum = []
    for data, labels in trainloader:
        data, labels = data.to(device), labels.to(device)
        spk_rec, _ = net(data, dataset.is_rate_encoded)
        loss = criterion(spk_rec, labels)
        optimizer.zero_grad()
        loss.backward()

        # Enable gradient clipping
        if config["grad_clip"]:
            nn.utils.clip_grad_norm_(net.parameters(), 1.0)

        # Enable weight clipping
        if config["weight_clip"]:
            with torch.no_grad():
                for param in net.parameters():
                    param.clamp_(-1, 1)

        optimizer.step()
        # scheduler.step()
        loss_accum.append(loss.item() / dataset.num_steps)
        lr_accum.append(optimizer.param_groups[0]["lr"])

    return loss_accum, lr_accum


def test(config, net, dataset, device="cpu"):
    """Calculate accuracy on full test set."""
    testloader = dataset.GetTestLoader()

    correct = 0
    total = 0
    with torch.no_grad():
        net.eval()
        for data in testloader:
            images, labels = data
            images, labels = images.to(device), labels.to(device)
            outputs, _ = net(images)
            accuracy = SF.accuracy_rate(outputs, labels, population_code=True, num_classes=dataset.num_classes)
            total += labels.size(0)
            correct += accuracy * labels.size(0)

    return 100 * correct / total


def dense_core_weights_and_biases(conv_layer, dir_name, l, n, is_quantized):
    if (is_quantized):
        weights = conv_layer.int_weight()
        biases = conv_layer.int_bias()
    else:
        weights = conv_layer.weight.data
        biases = conv_layer.bias.data

    # we want each file to have one of the 3x3x3 filters, so 27
    for i, (filter_tensor, bias) in enumerate(zip(weights, biases)):
        current_weights = filter_tensor.cpu().numpy().flatten()[::-1].tolist()
        current_weights.reverse()

        col = i % n  # assign each OC filter set to a PE column

        # weights for an entire column, 3 channel 3x3 filter
        for row in range(27):
            weight_file_name = f"pe{row}_{col}.txt"
            full_path = os.path.join(dir_name, weight_file_name)
            with open(full_path, 'a') as file:
                file.write(str(current_weights[row]))
                file.write("\n")

        bias_file_name = f"threshold{col}.txt"
        full_path = os.path.join(dir_name, bias_file_name)
        with open(full_path, 'a') as file:
            file.write(str(bias.cpu().numpy()))
            file.write("\n")


def sparse_core_weights_and_biases(conv_layer, dir_name, l, n, is_quantized):
    if (is_quantized):
        weights = conv_layer.int_weight()
        biases = conv_layer.int_bias()
    else:
        weights = conv_layer.weight.data
        biases = conv_layer.bias.data

    # Create a dictionary to store weights and biases for each file
    file_data = {i: [] for i in range(n)}

    for i, (filter_tensor, bias) in enumerate(zip(weights, biases)):
        file_index = i % n  # This will ensure the desired distribution

        current_weights = filter_tensor.cpu().numpy().flatten()[::-1].tolist()
        current_weights.append(bias.item())
        file_data[file_index].append(current_weights)

    for file_index, weights_set in file_data.items():
        file_name = f"conv{l}_nc{file_index}.txt"
        full_path = os.path.join(dir_name, file_name)

        with open(full_path, 'w') as file:
            for idx, w in enumerate(weights_set):
                file.write('\n'.join(map(str, w)))
                if idx != len(weights_set) - 1:  # Avoid writing extra newline characters after the last filter
                    file.write("\n")


def create_macro_file(net, dir_name, is_quantized, conv_1_1_ec_size, conv_1_2_ec_size, conv_2_1_ec_size,
                      conv_2_2_ec_size,
                      conv_3_1_ec_size, conv_3_2_ec_size, conv_3_3_ec_size, fc1_ec_size, fc2_ec_size):
    macro_path = os.path.abspath(f"{dir_name}/macros.txt")
    macro_path = macro_path.replace('\\', '/')

    with open(macro_path, 'w') as file:
        file.write(f'`define model_directory "{dir_name}"\n\n')

        file.write(f"`define conv_1_1_ec_size {conv_1_1_ec_size}\n")
        file.write(f"`define conv_1_2_ec_size {conv_1_2_ec_size}\n")
        file.write(f"`define conv_2_1_ec_size {conv_2_1_ec_size}\n")
        file.write(f"`define conv_2_2_ec_size {conv_2_2_ec_size}\n")
        file.write(f"`define conv_3_1_ec_size {conv_3_1_ec_size}\n")
        file.write(f"`define conv_3_2_ec_size {conv_3_2_ec_size}\n")
        file.write(f"`define conv_3_3_ec_size {conv_3_3_ec_size}\n")
        file.write(f"`define fc1_ec_size {fc1_ec_size}\n")
        file.write(f"`define fc2_ec_size {fc2_ec_size}\n\n")

        if is_quantized:
            weight_sfactor = net.Qconv1_1.quant_weight_scale().cpu().detach().numpy()
            file.write(f"`define w_sfactor_1_1 {str(weight_sfactor)}\n")
            weight_sfactor = net.Qconv1_2.quant_weight_scale().cpu().detach().numpy()
            file.write(f"`define w_sfactor_1_2 {str(weight_sfactor)}\n")
            weight_sfactor = net.Qconv2_1.quant_weight_scale().cpu().detach().numpy()
            file.write(f"`define w_sfactor_2_1 {str(weight_sfactor)}\n")
            weight_sfactor = net.Qconv2_2.quant_weight_scale().cpu().detach().numpy()
            file.write(f"`define w_sfactor_2_2 {str(weight_sfactor)}\n")
            weight_sfactor = net.Qconv3_1.quant_weight_scale().cpu().detach().numpy()
            file.write(f"`define w_sfactor_3_1 {str(weight_sfactor)}\n")
            weight_sfactor = net.Qconv3_2.quant_weight_scale().cpu().detach().numpy()
            file.write(f"`define w_sfactor_3_2 {str(weight_sfactor)}\n")
            weight_sfactor = net.Qconv3_3.quant_weight_scale().cpu().detach().numpy()
            file.write(f"`define w_sfactor_3_3 {str(weight_sfactor)}\n")
            weight_sfactor = net.Qfc1.quant_weight_scale().cpu().detach().numpy()
            file.write(f"`define w_sfactor_fc1 {str(weight_sfactor)}\n")
            weight_sfactor = net.Qfc2.quant_weight_scale().cpu().detach().numpy()
            file.write(f"`define w_sfactor_fc2 {str(weight_sfactor)}\n")

            bias_sfactor = net.Qconv1_1.quant_bias_scale().cpu().detach().numpy()
            file.write(f"`define b_sfactor_1_1 {str(bias_sfactor)}\n")
            bias_sfactor = net.Qconv1_2.quant_bias_scale().cpu().detach().numpy()
            file.write(f"`define b_sfactor_1_2 {str(bias_sfactor)}\n")
            bias_sfactor = net.Qconv2_1.quant_bias_scale().cpu().detach().numpy()
            file.write(f"`define b_sfactor_2_1 {str(bias_sfactor)}\n")
            bias_sfactor = net.Qconv2_2.quant_bias_scale().cpu().detach().numpy()
            file.write(f"`define b_sfactor_2_2 {str(bias_sfactor)}\n")
            bias_sfactor = net.Qconv3_1.quant_bias_scale().cpu().detach().numpy()
            file.write(f"`define b_sfactor_3_1 {str(bias_sfactor)}\n")
            bias_sfactor = net.Qconv3_2.quant_bias_scale().cpu().detach().numpy()
            file.write(f"`define b_sfactor_3_2 {str(bias_sfactor)}\n")
            bias_sfactor = net.Qconv3_3.quant_bias_scale().cpu().detach().numpy()
            file.write(f"`define b_sfactor_3_3 {str(bias_sfactor)}\n")
            bias_sfactor = net.Qfc1.quant_bias_scale().cpu().detach().numpy()
            file.write(f"`define b_sfactor_fc1 {str(bias_sfactor)}\n")
            bias_sfactor = net.Qfc2.quant_bias_scale().cpu().detach().numpy()
            file.write(f"`define b_sfactor_fc2 {str(bias_sfactor)}\n")

            weight_zpt = net.Qconv1_1.quant_weight_zero_point().cpu().detach().numpy()
            file.write(f"`define w_zpt_1_1 {str(weight_zpt)}\n")
            weight_zpt = net.Qconv1_2.quant_weight_zero_point().cpu().detach().numpy()
            file.write(f"`define w_zpt_1_2 {str(weight_zpt)}\n")
            weight_zpt = net.Qconv2_1.quant_weight_zero_point().cpu().detach().numpy()
            file.write(f"`define w_zpt_2_1 {str(weight_zpt)}\n")
            weight_zpt = net.Qconv2_2.quant_weight_zero_point().cpu().detach().numpy()
            file.write(f"`define w_zpt_2_2 {str(weight_zpt)}\n")
            weight_zpt = net.Qconv3_1.quant_weight_zero_point().cpu().detach().numpy()
            file.write(f"`define w_zpt_3_1 {str(weight_zpt)}\n")
            weight_zpt = net.Qconv3_2.quant_weight_zero_point().cpu().detach().numpy()
            file.write(f"`define w_zpt_3_2 {str(weight_zpt)}\n")
            weight_zpt = net.Qconv3_3.quant_weight_zero_point().cpu().detach().numpy()
            file.write(f"`define w_zpt_3_3 {str(weight_zpt)}\n")
            weight_zpt = net.Qfc1.quant_weight_zero_point().cpu().detach().numpy()
            file.write(f"`define w_zpt_fc1 {str(weight_zpt)}\n")
            weight_zpt = net.Qfc2.quant_weight_zero_point().cpu().detach().numpy()
            file.write(f"`define w_zpt_fc2 {str(weight_zpt)}\n")

            b_zpt = net.Qconv1_1.quant_bias_zero_point().cpu().detach().numpy()
            file.write(f"`define b_zpt_1_1 {str(b_zpt)}\n")
            b_zpt = net.Qconv1_2.quant_bias_zero_point().cpu().detach().numpy()
            file.write(f"`define b_zpt_1_2 {str(b_zpt)}\n")
            b_zpt = net.Qconv2_1.quant_bias_zero_point().cpu().detach().numpy()
            file.write(f"`define b_zpt_2_1 {str(b_zpt)}\n")
            b_zpt = net.Qconv2_2.quant_bias_zero_point().cpu().detach().numpy()
            file.write(f"`define b_zpt_2_2 {str(b_zpt)}\n")
            b_zpt = net.Qconv3_1.quant_bias_zero_point().cpu().detach().numpy()
            file.write(f"`define b_zpt_3_1 {str(b_zpt)}\n")
            b_zpt = net.Qconv3_2.quant_bias_zero_point().cpu().detach().numpy()
            file.write(f"`define b_zpt_3_2 {str(b_zpt)}\n")
            b_zpt = net.Qconv3_3.quant_bias_zero_point().cpu().detach().numpy()
            file.write(f"`define b_zpt_3_3 {str(b_zpt)}\n")
            b_zpt = net.Qfc1.quant_bias_zero_point().cpu().detach().numpy()
            file.write(f"`define b_zpt_fc1 {str(b_zpt)}\n")
            b_zpt = net.Qfc2.quant_bias_zero_point().cpu().detach().numpy()
            file.write(f"`define b_zpt_fc2 {str(b_zpt)}\n")

        else:
            file.write("`define w_sfactor_1_1 1.0 \n"
                       "`define w_sfactor_1_2 1.0\n"
                       "`define w_sfactor_2_1 1.0\n"
                       "`define w_sfactor_2_2 1.0\n"
                       "`define w_sfactor_3_1 1.0\n"
                       "`define w_sfactor_3_2 1.0\n"
                       "`define w_sfactor_3_3 1.0\n"
                       "`define w_sfactor_fc1 1.0\n"
                       "`define w_sfactor_fc2 1.0\n"
                       "`define b_sfactor_1_1 1.0\n"
                       "`define b_sfactor_1_2 1.0\n"
                       "`define b_sfactor_2_1 1.0\n"
                       "`define b_sfactor_2_2 1.0\n"
                       "`define b_sfactor_3_1 1.0\n"
                       "`define b_sfactor_3_2 1.0\n"
                       "`define b_sfactor_3_3 1.0\n"
                       "`define b_sfactor_fc1 1.0\n"
                       "`define b_sfactor_fc2 1.0\n"
                       "`define w_zpt_1_1 0.0\n"
                       "`define w_zpt_1_2 0.0\n"
                       "`define w_zpt_2_1 0.0\n"
                       "`define w_zpt_2_2 0.0\n"
                       "`define w_zpt_3_1 0.0\n"
                       "`define w_zpt_3_2 0.0\n"
                       "`define w_zpt_3_3 0.0\n"
                       "`define w_zpt_fc1 0.0\n"
                       "`define w_zpt_fc2 0.0\n"
                       "`define b_zpt_1_1 0.0\n"
                       "`define b_zpt_1_2 0.0\n"
                       "`define b_zpt_2_1 0.0\n"
                       "`define b_zpt_2_2 0.0\n"
                       "`define b_zpt_3_1 0.0\n"
                       "`define b_zpt_3_2 0.0\n"
                       "`define b_zpt_3_3 0.0\n"
                       "`define b_zpt_fc1 0.0\n"
                       "`define b_zpt_fc2 0.0")

        print(f'`include "{macro_path}"\n')