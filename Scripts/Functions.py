import torch, torch.nn as nn
import snntorch.functional as SF

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
    i = 0
    for data, labels in trainloader:
        data, labels = data.to(device), labels.to(device)
        spk_rec, _ = net(data, dataset.is_rate_encoded)
        loss = criterion(spk_rec, labels)
        optimizer.zero_grad()
        loss.backward()

        ## Enable gradient clipping
        if config["grad_clip"]:
            nn.utils.clip_grad_norm_(net.parameters(), 1.0)

        ## Enable weight clipping
        if config["weight_clip"]:
            with torch.no_grad():
                for param in net.parameters():
                    param.clamp_(-1, 1)

        optimizer.step()
        # scheduler.step()
        loss_accum.append(loss.item() / config["num_steps"])
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