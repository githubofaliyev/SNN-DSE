#Three lines to make our compiler able to draw:
import matplotlib
matplotlib.use('Agg')

import matplotlib.pyplot as plt
import numpy as np

xpoints = np.array([1, 2, 3, 4])
y1points = np.array([2, 3, 5, 10])
y2points = np.array([2, 4, 6, 8])

plt.plot(xpoints, y1points, label="hidden layer")
plt.plot(xpoints, y2points, label="output layer")

plt.xlabel("# neurons per layer")
plt.ylabel("Latency")

plt.legend()
plt.show()



