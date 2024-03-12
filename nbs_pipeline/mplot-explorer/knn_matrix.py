import pyscamp as mp
import numpy as np
import math
#from kneed import KneeLocator
import sys
import matplotlib.pyplot as plt
from graph import KNNGraph, GraphNode
import knn_plotting

arr = np.fromfile(sys.argv[1],sep='\n')
sublen = int(sys.argv[2])
n = len(arr) - sublen + 1
k = int(sys.argv[3])
thresh = float(sys.argv[4])
print('KNN computing...')
reduced_size = k
knn_mat = mp.selfjoin_matrix(arr, sublen, threshold=thresh, pearson=True, mwidth=reduced_size, mheight=reduced_size);
for i in range(reduced_size):
  knn_mat[i:,i] = knn_mat[i,i:]
print('KNN computed...')
factor = n // reduced_size

knn_plotting.plot_matrix(knn_mat, arr, n, factor, 'fig.png') 
