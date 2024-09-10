import tonic
import tonic.transforms as transforms

import torch
from torch.utils.data import DataLoader

# transform that converts all the input data to 0's and 1's.
def ToBinary(events):
    events[events > 0] = 1

    return events


class NMNIST:
    def __init__(self, config, data_path):
        self.config = config
        self.data_path = data_path

        self.name = "NMNIST"
        self.batch_size = 3000
        self.num_classes = 10

        self.input_sensor_size = tonic.datasets.NMNIST.sensor_size
        self.frame_transform = transforms.Compose([transforms.Denoise(filter_time=10000),
                                              transforms.ToFrame(sensor_size=self.input_sensor_size,
                                                                 time_window=self.config['time_window']),
                                              ToBinary
                                              ])

        self.train_set = tonic.datasets.NMNIST(save_to=self.data_path, transform=self.frame_transform, train=True)
        self.test_set = tonic.datasets.NMNIST(save_to=self.data_path, transform=self.frame_transform, train=False)

        self.cached_train_set = tonic.DiskCachedDataset(self.train_set, cache_path=self.data_path + '/cache/NMNIST Binary/train')
        self.cached_test_set = tonic.DiskCachedDataset(self.test_set, cache_path=self.data_path + '/cache/NMNIST Binary/test')

    def GetTrainLoader(self):
        return DataLoader(self.cached_train_set, batch_size=self.batch_size,
                                 collate_fn=tonic.collation.PadTensors(batch_first=False), shuffle=True)

    def GetTestLoader(self):
        return DataLoader(self.cached_test_set, batch_size=self.batch_size,
                                collate_fn=tonic.collation.PadTensors(batch_first=False))

    def GetSampleLoader(self):
        return DataLoader(self.cached_test_set, batch_size=1, collate_fn=tonic.collation.PadTensors(batch_first=False))



class DVSGesture:
    def __init__(self, config, data_path):
        self.config = config
        self.data_path = data_path

        self.name = "DVSGesture"
        self.batch_size = 40
        self.num_classes = 11

        self.sensor_size = tonic.datasets.DVSGesture.sensor_size
        self.input_sensor_size = (64, 64, 2)
        self.frame_transform = transforms.Compose([transforms.Denoise(filter_time=10000),
                                              transforms.ToFrame(sensor_size=self.input_sensor_size,
                                                                 time_window=self.config['time_window']),
                                              ToBinary
                                              ])

        self.train_set = tonic.datasets.DVSGesture(save_to=self.data_path, transform=self.frame_transform, train=True)
        self.test_set = tonic.datasets.DVSGesture(save_to=self.data_path, transform=self.frame_transform, train=False)

        self.cached_train_set = tonic.DiskCachedDataset(self.train_set, cache_path=self.data_path + '/cache/DVSGesture Binary/train')
        self.cached_test_set = tonic.DiskCachedDataset(self.test_set, cache_path=self.data_path + '/cache/DVSGesture Binary/test')

    def GetTrainLoader(self):
        return DataLoader(self.cached_train_set, batch_size=self.batch_size,
                                 collate_fn=tonic.collation.PadTensors(batch_first=False), shuffle=True)

    def GetTestLoader(self):
        return DataLoader(self.cached_test_set, batch_size=self.batch_size,
                                collate_fn=tonic.collation.PadTensors(batch_first=False))

    def GetSampleLoader(self):
        return DataLoader(self.cached_test_set, batch_size=1, collate_fn=tonic.collation.PadTensors(batch_first=False))


class CIFAR10DVS:
    def __init__(self, config, data_path):
        self.config = config
        self.data_path = data_path

        self.name = "CIFAR10DVS"
        self.batch_size = 128
        self.num_classes = 10

        self.sensor_size = tonic.datasets.CIFAR10DVS.sensor_size
        self.input_sensor_size = (64, 64, 2)
        self.frame_transform = transforms.Compose([transforms.Denoise(filter_time=10000),
                                                   transforms.ToFrame(sensor_size=self.input_sensor_size,
                                                                      time_window=self.config['time_window']),
                                                   ToBinary
                                                   ])

        dataset = tonic.datasets.CIFAR10DVS(save_to=self.data_path, transform=self.frame_transform)

        self.cached_dataset = tonic.DiskCachedDataset(dataset, cache_path=self.data_path + '/cache/CIFAR10DVS(0.5) Binary/')
        self.cached_train_set, self.cached_test_set = torch.utils.data.random_split(self.cached_dataset, [9000, 1000])

    def GetTrainLoader(self):
        return DataLoader(self.cached_train_set, batch_size=self.batch_size, collate_fn=tonic.collation.PadTensors(batch_first=False), shuffle=True)

    def GetTestLoader(self):
        return DataLoader(self.cached_test_set, batch_size=self.batch_size, collate_fn=tonic.collation.PadTensors(batch_first=False))

    def GetSampleLoader(self):
        return DataLoader(self.cached_dataset, batch_size=1, collate_fn=tonic.collation.PadTensors(batch_first=False))