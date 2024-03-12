import pyscamp as mp
import numpy as np
import math
#from kneed import KneeLocator
import sys
#import matplotlib.pyplot as plt
from graph import KNNGraph, GraphNode

arr = np.fromfile(sys.argv[1],sep='\n')
sublen = int(sys.argv[2])
n = len(arr) - sublen + 1
k = int(sys.argv[3])
thresh = float(sys.argv[4])
print('KNN computing...')
knn_lst = mp.selfjoin_knn(arr, sublen, k=k, threshold=thresh, pearson=True);
print('KNN computed...')
print('Constructing graph...')
g = KNNGraph(knn_lst)
print('Graph Constructed.')
print('Combining graph')
g.combine()
print('Graph combined')
with open('graph_out.txt', 'w') as fp:
  fp.write(str(g))
