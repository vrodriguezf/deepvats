import pyscamp as mp
import numpy as np
import math
import sys
import matplotlib.pyplot as plt
import knn_plotting

arr = np.fromfile(sys.argv[1],sep='\n')
sublen = int(sys.argv[2])
n = len(arr) - sublen + 1

knn_plotting.plot_matrix_interactive(arr, None, sublen, 500) 
