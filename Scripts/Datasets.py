from torchvision import datasets, transforms
from torch.utils.data import DataLoader
import torch
import numpy as np

try:
    import tonic
    import tonic.transforms as T
    HAS_TONIC = True
except ImportError:
    HAS_TONIC = False


class DatasetBase():
    def __init__(self):
        self.num_classes = None
        self.num_train_samples = None
        self.num_epochs = None
        self.num_steps = None
        self.input_channels = 3
        self.input_size = 32

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
        self.num_classes = 10
        self.input_channels = 3
        self.input_size = 32

        self.batch_size = 512
        self.num_epochs = 225
        self.pop_size = 1000
        self.num_steps = 2
        self.is_rate_encoded = False
        self.is_event_encoded = False

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

        self.name = "CIFAR100"
        self.num_classes = 100
        self.input_channels = 3
        self.input_size = 32

        self.batch_size = 512
        self.num_epochs = 500
        self.pop_size = 5000
        self.num_steps = 2
        self.is_rate_encoded = False
        self.is_event_encoded = False

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

        self.name = "SVHN"
        self.num_classes = 10
        self.input_channels = 3
        self.input_size = 32

        self.batch_size = 512
        self.num_epochs = 225
        self.pop_size = 1000
        self.num_steps = 2
        self.is_rate_encoded = False
        self.is_event_encoded = False

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

        self.name = "CIFAR10Rate"
        self.num_classes = 10
        self.input_channels = 3
        self.input_size = 32

        self.num_steps = 25
        self.batch_size = 128
        self.num_epochs = 100
        self.pop_size = 1000
        self.is_rate_encoded = True
        self.is_event_encoded = False

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


def _dvs_collate(batch):
    """Collate function for DVS datasets that returns (T, B, C, H, W) tensors."""
    data, targets = zip(*batch)
    data = torch.stack([torch.tensor(d, dtype=torch.float32) for d in data])
    targets = torch.tensor(targets)
    return data, targets


class DVSGesture(DatasetBase):
    def __init__(self, config, data_path):
        assert HAS_TONIC, "tonic library required for DVS datasets: pip install tonic"
        super().__init__()
        self.config = config
        self.data_path = data_path

        self.name = "DVSGesture"
        self.num_classes = 11
        self.input_channels = 2
        self.input_size = 32

        self.batch_size = 16
        self.num_epochs = 200
        self.pop_size = 200
        self.num_steps = 4
        self.is_rate_encoded = False
        self.is_event_encoded = True

        sensor_size = tonic.datasets.DVSGesture.sensor_size
        self.transform = tonic.transforms.Compose([
            tonic.transforms.Denoise(filter_time=10000),
            tonic.transforms.ToFrame(sensor_size=sensor_size, n_time_bins=self.num_steps),
        ])

        self.train_set = tonic.datasets.DVSGesture(
            save_to=data_path, train=True, transform=self.transform)
        self.test_set = tonic.datasets.DVSGesture(
            save_to=data_path, train=False, transform=self.transform)

    def GetTrainLoader(self):
        return DataLoader(self.train_set, batch_size=self.batch_size, shuffle=True,
                          collate_fn=_dvs_collate, drop_last=True)

    def GetTestLoader(self):
        return DataLoader(self.test_set, batch_size=self.batch_size, shuffle=False,
                          collate_fn=_dvs_collate)

    def GetSampleLoader(self):
        return DataLoader(self.test_set, batch_size=1, shuffle=False,
                          collate_fn=_dvs_collate)


class NMNIST(DatasetBase):
    def __init__(self, config, data_path):
        assert HAS_TONIC, "tonic library required for DVS datasets: pip install tonic"
        super().__init__()
        self.config = config
        self.data_path = data_path

        self.name = "NMNIST"
        self.num_classes = 10
        self.input_channels = 2
        self.input_size = 32

        self.batch_size = 64
        self.num_epochs = 200
        self.pop_size = 200
        self.num_steps = 4
        self.is_rate_encoded = False
        self.is_event_encoded = True

        sensor_size = tonic.datasets.NMNIST.sensor_size
        self.transform = tonic.transforms.Compose([
            tonic.transforms.Denoise(filter_time=10000),
            tonic.transforms.ToFrame(sensor_size=sensor_size, n_time_bins=self.num_steps),
        ])

        self.train_set = tonic.datasets.NMNIST(
            save_to=data_path, train=True, transform=self.transform)
        self.test_set = tonic.datasets.NMNIST(
            save_to=data_path, train=False, transform=self.transform)

    def GetTrainLoader(self):
        return DataLoader(self.train_set, batch_size=self.batch_size, shuffle=True,
                          collate_fn=_dvs_collate, drop_last=True)

    def GetTestLoader(self):
        return DataLoader(self.test_set, batch_size=self.batch_size, shuffle=False,
                          collate_fn=_dvs_collate)

    def GetSampleLoader(self):
        return DataLoader(self.test_set, batch_size=1, shuffle=False,
                          collate_fn=_dvs_collate)


class DVSCIFAR10(DatasetBase):
    def __init__(self, config, data_path):
        assert HAS_TONIC, "tonic library required for DVS datasets: pip install tonic"
        super().__init__()
        self.config = config
        self.data_path = data_path

        self.name = "DVSCIFAR10"
        self.num_classes = 10
        self.input_channels = 2
        self.input_size = 32

        self.batch_size = 16
        self.num_epochs = 200
        self.pop_size = 200
        self.num_steps = 4
        self.is_rate_encoded = False
        self.is_event_encoded = True

        sensor_size = tonic.datasets.CIFAR10DVS.sensor_size
        self.transform = tonic.transforms.Compose([
            tonic.transforms.Denoise(filter_time=10000),
            tonic.transforms.ToFrame(sensor_size=sensor_size, n_time_bins=self.num_steps),
        ])

        self.train_set = tonic.datasets.CIFAR10DVS(
            save_to=data_path, transform=self.transform)
        self.test_set = tonic.datasets.CIFAR10DVS(
            save_to=data_path, transform=self.transform)

    def GetTrainLoader(self):
        return DataLoader(self.train_set, batch_size=self.batch_size, shuffle=True,
                          collate_fn=_dvs_collate, drop_last=True)

    def GetTestLoader(self):
        return DataLoader(self.test_set, batch_size=self.batch_size, shuffle=False,
                          collate_fn=_dvs_collate)

    def GetSampleLoader(self):
        return DataLoader(self.test_set, batch_size=1, shuffle=False,
                          collate_fn=_dvs_collate)
