import matplotlib.pyplot as plt
import numpy as np
import math
import pyscamp as mp
from mpl_toolkits.axes_grid1.inset_locator import inset_axes

fig = None
ax2 = None
ax3 = None
ax4 = None
a_global = None
b_global = None
sublen_global = None
matrix_dim_global = None
gs = None
cax = None
cache = {}

def get_matrix(st_a, ed_a, st_b, ed_b):
    global a_global
    global b_global
    global cache

    a = a_global[st_a:ed_a]
    b = b_global[st_b:ed_b]

    cache_key = (st_a, ed_a, st_b, ed_b)
    matrix = None
    if cache_key in cache:
       matrix = cache[cache_key]
    else:
      if len(a) > 1000 * matrix_dim_global and len(b) > 1000 * matrix_dim_global:
        # Currently GPU Matrix summaries can leave some spotty output if the input size is not large enough. So only allow GPU computation when we can be sure we will fill in the whole matrix
        # TODO(zpzim): Implement GPU Matrix summaries which will generate the same output as the CPU version.
        matrix = mp.abjoin_matrix(a, b, sublen_global, mwidth=matrix_dim_global, mheight=matrix_dim_global, pearson=True)
      else:
        matrix = mp.abjoin_matrix(a, b, sublen_global, mwidth=matrix_dim_global, mheight=matrix_dim_global, gpus=[], pearson=True)
      cache[cache_key] = matrix
    matrix[np.isnan(matrix)] = 0
    return matrix


def redraw_matrix(st_a, ed_a, st_b, ed_b):
    global ax2
    global ax3
    global ax4
    global cax

    matrix = get_matrix(st_a, ed_a, st_b, ed_b) 
    
    cax.remove()
    cax = ax4.matshow(matrix, extent=[st_a, ed_a, ed_b, st_b], interpolation='none')
    ax4.set_adjustable('box')
    ax4.set_aspect('auto')
    ax4.autoscale(False)
    ax4.callbacks.connect('ylim_changed', on_ylims_change)
    ax4.callbacks.connect('xlim_changed', on_xlims_change)


def on_xlims_change(event_ax):
    global ax2
    global ax3
    global ax4
    global cax
    st_a, ed_a = event_ax.get_xlim()
    ed_b, st_b = ax3.get_ylim()
    st_a = int(st_a)
    ed_a = int(ed_a)
    st_b = int(st_b)
    ed_b = int(ed_b)
    print(st_a, ed_a, st_b, ed_b)
    redraw_matrix(st_a, ed_a, st_b, ed_b)

def on_ylims_change(event_ax):
    global ax2
    global ax3
    global ax4
    global cax
    st_a, ed_a = ax2.get_xlim()
    ed_b, st_b = event_ax.get_ylim()
    st_a = int(st_a)
    ed_a = int(ed_a)
    st_b = int(st_b)
    ed_b = int(ed_b)
    print(st_a, ed_a, st_b, ed_b)
    redraw_matrix(st_a, ed_a, st_b, ed_b)

  

def plot_matrix_interactive(a, b, sublen, matrix_dim, filename=None):
  if b is None:
    b = a

  global fig
  global ax2
  global ax3
  global ax4
  global a_global
  global b_global
  global sublen_global
  global matrix_dim_global
  global cax
  a_global = np.copy(a)
  b_global = np.copy(b)
  sublen_global = sublen
  matrix_dim_global = matrix_dim
  n_x = len(a) - sublen + 1
  n_y = len(b) - sublen + 1

  ratio = len(a) / len(b)

  matrix_dim_a = math.floor(ratio * matrix_dim)
  matrix_dim_b = matrix_dim

  matrix = get_matrix(0, len(a), 0, len(b))
  print(matrix.dtype)
  #matrix = mp.abjoin_matrix(a, b, sublen, mwidth=matrix_dim, mheight=matrix_dim, gpus=[], pearson=True)

  fig = plt.figure(constrained_layout=False, facecolor='0.9', figsize=(32,32))
  gs = fig.add_gridspec(nrows=2, ncols=2,  hspace=0, wspace=0, width_ratios=[1,3], height_ratios=[1,3])

  ax2 = fig.add_subplot(gs[:-1,-1])
  ax3 = fig.add_subplot(gs[-1,:-1])
  ax4 = fig.add_subplot(gs[-1, -1], sharex=ax2, sharey=ax3)

  cax = ax4.matshow(matrix, extent=[0, n_x, n_y, 0], interpolation='none')
  #cax = ax4.matshow(matrix, interpolation='none')
  ax4.set_adjustable('box')
  ax4.set_aspect('auto')
  ax4.autoscale(False)
  axins = inset_axes(ax4, width='100%', height='5%', loc ='lower center', borderpad=-5)
  fig.colorbar(cax, cax=axins, orientation='horizontal')
  

  ax4.set_axis_off()
  ax4.axis('off')


  ax2.plot([i for i in range(n_x)], a[:n_x])
  ax2.set_xlim(xmin=0, xmax=n_x)
  ax2.xaxis.set_ticks_position('top')
  ax2.set_axisbelow(False)
  ax3.plot(b[:n_y], [i for i in range(n_y)])
  ax3.set_ylim(ymin=0, ymax=n_y)
  ax3.invert_yaxis()
  ax3.invert_xaxis()
  ax2.callbacks.connect('xlim_changed', on_xlims_change)
  ax3.callbacks.connect('ylim_changed', on_ylims_change)
  ax4.callbacks.connect('ylim_changed', on_xlims_change)
  ax4.callbacks.connect('xlim_changed', on_ylims_change)
  plt.show()
  if filename is not None:
    fig.savefig(filename, bbox_inches='tight')
  return fig
    




def plot_matrix(matrix, arr, n, scale_factor, outfile):
  plt.tight_layout()
  fig = plt.figure(constrained_layout=False, facecolor='0.9', figsize=(32,32))
  gs = fig.add_gridspec(nrows=2, ncols=2,  hspace=0, wspace=0, width_ratios=[1,3], height_ratios=[1,3])

  ax2 = fig.add_subplot(gs[:-1,-1])
  ax3 = fig.add_subplot(gs[-1,:-1])
  ax4 = fig.add_subplot(gs[-1, -1])

  ax4.matshow(matrix)

  ax4.set_axis_off()
  ax4.axis('off')


  ax2.plot([i for i in range(n)], arr[:n])
  ax2.set_xlim(xmin=0, xmax=n)
  ax2.xaxis.set_ticks_position('top')
  ax2.set_axisbelow(False)
  ax3.plot(arr[:n], [i for i in range(n)])
  ax3.set_ylim(ymin=0, ymax=n)
  ax3.invert_yaxis()
  ax3.invert_xaxis()
  fig.savefig(outfile, bbox_inches='tight')
  plt.close(fig)
