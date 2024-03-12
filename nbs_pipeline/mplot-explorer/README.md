# mplot-explorer
Example Python script showing how to explore mplots interactively using [pyscamp](https://github.com/zpzim/SCAMP). This is a rudimentary implementation which does not support optimized panning.

![Mplot Example](https://github.com/zpzim/mplot-explorer/blob/cda8e19b91c3fa3c6dfc5e1b9daa9167c2483d89/mplot_explorer.gif)

Usage: 
```
# numpy array representing the time series
ts_a = np.fromfile('example.txt', sep='\n')
ts_b = None
# subsequence length for mplot
sublen = 100
# output dimension (square of size NxN) of the mplot shown in the figure (output will be pooled to this size)
# This implementation does not support rectangles but you could easily do it.
out_dim = 500
import knn_plotting
knn_plotting.plot_matrix_interactive(ts_a, ts_b, sublen, out_dim)
# A matplotlib figure window will be created which you can interact
# with while this script is running. You can zoom in on features you
# are interested in and the mplot will be dynamically recomputed from
# the new boundary conditions based on where you zoomed. You can zoom
# out by hitting the back button. Panning is not optimized and so will
# be recomputed every single time the bounds are updated. I don't
# recommend panning without implementing some optimizations first.
```
