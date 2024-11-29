from torchvision import datasets, transforms
from torch.utils.data import DataLoader


class DatasetBase():
    def __init__(self):
        self.num_classes = None
        self.num_train_samples = None
        self.num_epochs = None

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

        self.name = "CIFAR10"
        self.num_steps = 2
        self.batch_size = 512
        self.num_classes = 10
        self.num_epochs = 225
        self.pop_size = 1000
        self.is_rate_encoded = False

        self.train_set = datasets.CIFAR10(root=self.data_path, train=True, download=True,
                                          transform=self.config["transform_train"])
        self.test_set = datasets.CIFAR10(root=self.data_path, train=False, download=True,
                                         transform=self.config["transform_test"])

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

        self.name = "CIFAR100"
        self.num_steps = 2
        self.batch_size = 512
        self.num_classes = 100
        self.num_epochs = 500
        self.pop_size = 5000
        self.is_rate_encoded = False

        self.train_set = datasets.CIFAR100(root=self.data_path, train=True, download=True,
                                           transform=self.config["transform_train"])
        self.test_set = datasets.CIFAR100(root=self.data_path, train=False, download=True,
                                          transform=self.config["transform_test"])

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

        self.name = "SVHN"
        self.num_steps = 2
        self.batch_size = 512
        self.num_classes = 10
        self.num_epochs = 225
        self.pop_size = 1000
        self.is_rate_encoded = False

        self.train_set = datasets.SVHN(root=data_path, split="train", download=True,
                                       transform=self.config["transform_train"])
        self.test_set = datasets.SVHN(root=data_path, split="test", download=True,
                                      transform=self.config["transform_test"])

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

        self.name = "CIFAR10 Rate"
        self.num_steps = 25
        self.batch_size = 128
        self.num_classes = 10
        self.num_epochs = 100
        self.pop_size = 1000
        self.is_rate_encoded = True

        self.train_set = datasets.CIFAR10(root=self.data_path, train=True, download=True,
                                          transform=self.config["transform_train"])
        self.test_set = datasets.CIFAR10(root=self.data_path, train=False, download=True,
                                         transform=self.config["transform_test"])

    def GetTrainLoader(self):
        return DataLoader(self.train_set, batch_size=self.batch_size, shuffle=True)

    def GetTestLoader(self):
        return DataLoader(self.test_set, batch_size=self.batch_size, shuffle=False)

    def GetSampleLoader(self):
        return DataLoader(self.test_set, batch_size=1, shuffle=False)
