from torchvision import transforms

direct_config = {
            "seed": 0,  # random seed

            # Quantization
            "num_bits": 4,  # Bit resolution

            # Network parameters
            "grad_clip": False,  # Whether to clip gradients
            "weight_clip": False,  # Whether to clip weights
            "batch_norm": True,  # Whether to use batch normalization
            "dropout": 0.102,  # Dropout rate
            "beta": 0.15,  # Decay rate parameter (beta)
            "threshold": 0.5,  # Threshold parameter (theta)
            "lr": 5.0e-3,  # Initial learning rate
            "slope": 1.0,  # Slope value (k)

            # Fixed params
            "correct_rate": 1.0,  # Correct rate
            "incorrect_rate": 0.0,  # Incorrect rate
            "betas": (0.9, 0.999),  # Adam optimizer beta values
            "t_0": 4690,  # Initial frequency of the cosine annealing scheduler
            "eta_min": 0,  # Minimum learning rate

            "transform_train": transforms.Compose([
                transforms.RandomCrop(32, padding=4),
                transforms.RandomHorizontalFlip(),
                transforms.ToTensor(),
                transforms.Normalize((0.4914, 0.4822, 0.4465), (0.2023, 0.1994, 0.2010))
            ]),

            "transform_test": transforms.Compose([
                transforms.ToTensor(),
                transforms.Normalize((0.4914, 0.4822, 0.4465), (0.2023, 0.1994, 0.2010))
            ])
        }