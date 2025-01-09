from torchvision import datasets, transforms
from torch.utils.data import DataLoader


class DatasetBase():
    def __init__(self):
        self.num_classes = None
        self.num_train_samples = None
        self.num_epochs = None
        self.num_steps = None

    def GetTrainLoader(self):
        raise NotImplementedError

    def GetTestLoader(self):
        raise NotImplementedError

    def GetSampleLoader(self):
        raise NotImplementedError


class CIFAR10(DatasetBase):
    def __init__(self, config, data_path):
        super().__init__()
        self.config = config
        self.data_path = data_path

        # Do not change. Hard values.
        self.name = "CIFAR10"
        self.num_classes = 10

        # Free to change.
        self.batch_size = 512
        self.num_epochs = 225
        self.pop_size = 1000
        self.num_steps = 2  # Hybrid hardware is hardcoded with 2 time steps. If num_steps is changed here than time steps has to be changed in the hardware code as well.
        self.is_rate_encoded = False

        self.transform_train = transforms.Compose([
            transforms.RandomCrop(32, padding=4),
            transforms.RandomHorizontalFlip(),
            transforms.ToTensor(),
            transforms.Normalize((0.4914, 0.4822, 0.4465), (0.2023, 0.1994, 0.2010)),
            # transforms.Normalize((0.5071, 0.4867, 0.4408), (0.2675, 0.2565, 0.2761)),
        ])

        self.transform_test = transforms.Compose([
            transforms.ToTensor(),
            transforms.Normalize((0.4914, 0.4822, 0.4465), (0.2023, 0.1994, 0.2010)),
            # transforms.Normalize((0.5071, 0.4867, 0.4408), (0.2675, 0.2565, 0.2761)),
        ])

        self.train_set = datasets.CIFAR10(root=self.data_path, train=True, download=True,
                                          transform=self.transform_train)
        self.test_set = datasets.CIFAR10(root=self.data_path, train=False, download=True,
                                         transform=self.transform_train)

    def GetTrainLoader(self):
        return DataLoader(self.train_set, batch_size=self.batch_size, shuffle=True)

    def GetTestLoader(self):
        return DataLoader(self.test_set, batch_size=self.batch_size, shuffle=False)

    def GetSampleLoader(self):
        return DataLoader(self.test_set, batch_size=1, shuffle=False)


class CIFAR100(DatasetBase):
    def __init__(self, config, data_path):
        super().__init__()
        self.config = config
        self.data_path = data_path

        # Do not change. Hard values.
        self.name = "CIFAR100"
        self.num_classes = 100

        # Free to change.
        self.batch_size = 512
        self.num_epochs = 500
        self.pop_size = 5000
        self.num_classes = 100
        self.num_steps = 2  # Hybrid hardware is hardcoded with 2 time steps. If time_steps is changes here than time steps has to be changed in the hardware code as well.
        self.is_rate_encoded = False

        self.transform_train = transforms.Compose([
            transforms.RandomCrop(32, padding=4),
            transforms.RandomHorizontalFlip(),
            transforms.ToTensor(),
            # transforms.Normalize((0.4914, 0.4822, 0.4465), (0.2023, 0.1994, 0.2010)),
            transforms.Normalize((0.5071, 0.4867, 0.4408), (0.2675, 0.2565, 0.2761)),
        ])

        self.transform_test = transforms.Compose([
            transforms.ToTensor(),
            # transforms.Normalize((0.4914, 0.4822, 0.4465), (0.2023, 0.1994, 0.2010)),
            transforms.Normalize((0.5071, 0.4867, 0.4408), (0.2675, 0.2565, 0.2761)),
        ])

        self.train_set = datasets.CIFAR100(root=self.data_path, train=True, download=True,
                                           transform=self.transform_train)
        self.test_set = datasets.CIFAR100(root=self.data_path, train=False, download=True,
                                          transform=self.transform_test)

    def GetTrainLoader(self):
        return DataLoader(self.train_set, batch_size=self.batch_size, shuffle=True)

    def GetTestLoader(self):
        return DataLoader(self.test_set, batch_size=self.batch_size, shuffle=False)

    def GetSampleLoader(self):
        return DataLoader(self.test_set, batch_size=1, shuffle=False)


class SVHN(DatasetBase):
    def __init__(self, config, data_path):
        super().__init__()
        self.config = config
        self.data_path = data_path

        # Do not change. Hard values.
        self.name = "SVHN"
        self.num_classes = 10

        # Free to change.
        self.batch_size = 512
        self.num_epochs = 225
        self.pop_size = 1000
        self.num_steps = 2  # Hybrid hardware is hardcoded with 2 time steps. If time_steps is changes here than time steps has to be changed in the hardware code as well.
        self.is_rate_encoded = False

        self.transform_train = transforms.Compose([
            transforms.ToTensor(),
            transforms.Normalize((0.4376821, 0.4437697, 0.47280442), (0.19803012, 0.20101562, 0.19703614))
        ])

        self.transform_test = transforms.Compose([
            transforms.ToTensor(),
            transforms.Normalize((0.4376821, 0.4437697, 0.47280442), (0.19803012, 0.20101562, 0.19703614))
            # mean and std for SVHN to improve test acc.
        ])

        self.train_set = datasets.SVHN(root=data_path, split="train", download=True,
                                       transform=self.transform_train)
        self.test_set = datasets.SVHN(root=data_path, split="test", download=True,
                                      transform=self.transform_test)

    def GetTrainLoader(self):
        return DataLoader(self.train_set, batch_size=self.batch_size, shuffle=True)

    def GetTestLoader(self):
        return DataLoader(self.test_set, batch_size=self.batch_size, shuffle=False)

    def GetSampleLoader(self):
        return DataLoader(self.test_set, batch_size=1, shuffle=False)


class CIFAR10Rate(DatasetBase):
    def __init__(self, config, data_path):
        super().__init__()
        self.config = config
        self.data_path = data_path

        # Do not change. Hard values.
        self.name = "CIFAR10Rate"
        self.num_classes = 10

        # Free to change.
        self.num_steps = 25  # Can change num_steps freely as sparse hardware has a num_steps macro that will be set automaticaly in the Extract.py script.
        self.batch_size = 128
        self.num_epochs = 100
        self.pop_size = 1000
        self.is_rate_encoded = True

        self.transform_train = transforms.Compose([
            transforms.RandomCrop(32, padding=4),
            transforms.RandomHorizontalFlip(),
            transforms.ToTensor(),
            transforms.Normalize((0.4914, 0.4822, 0.4465), (0.2023, 0.1994, 0.2010))
        ])

        self.transform_test = transforms.Compose([
            transforms.ToTensor(),
            transforms.Normalize((0.4914, 0.4822, 0.4465), (0.2023, 0.1994, 0.2010)),
        ])

        self.train_set = datasets.CIFAR10(root=self.data_path, train=True, download=True,
                                          transform=self.transform_train)
        self.test_set = datasets.CIFAR10(root=self.data_path, train=False, download=True,
                                         transform=self.transform_test)

    def GetTrainLoader(self):
        return DataLoader(self.train_set, batch_size=self.batch_size, shuffle=True)

    def GetTestLoader(self):
        return DataLoader(self.test_set, batch_size=self.batch_size, shuffle=False)

    def GetSampleLoader(self):
        return DataLoader(self.test_set, batch_size=1, shuffle=False)
