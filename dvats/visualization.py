# AUTOGENERATED! DO NOT EDIT! File to edit: ../nbs/visualization.ipynb.

# %% auto 0
__all__ = ['plot_TS', 'plot_validation_ts_ae', 'plot_mask']

# %% ../nbs/visualization.ipynb 3
from fastcore.all import *
import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import torch

# %% ../nbs/visualization.ipynb 6
@delegates(pd.DataFrame.plot)
def plot_TS(df:pd.core.frame.DataFrame, **kwargs):
    df.plot(subplots=True, **kwargs)
    plt.show()

# %% ../nbs/visualization.ipynb 8
def plot_validation_ts_ae(prediction:np.array, original:np.array, title_str = "Validation plot", fig_size = (15,15), anchor = (-0.01, 0.89), window_num = 0, return_fig=True, title_pos = 0.9):
    # Create the figure
    fig = plt.figure(figsize=(fig_size[0],fig_size[1]))
    # Create the subplot axes
    axes = fig.subplots(nrows=original.shape[2], ncols=1)
    # We iterate over the sensor data and plot both the original and the prediction
    for i,ax in zip(range(original.shape[2]),fig.axes):
        ax.plot(original[window_num,:,i], label='Original Data')
        ax.plot(prediction[window_num,:,i], label='Prediction')
    # Handle the legend configuration and position
    lines, labels = fig.axes[-1].get_legend_handles_labels()
    fig.legend(lines, labels,loc='upper left', ncol=2)
    # Write the plot title (and position it closer to the top of the graph)
    fig.suptitle(title_str, y = title_pos)
    # Tight results:
    fig.tight_layout()
    # Returns
    if return_fig:
        return fig
    fig
    return None

# %% ../nbs/visualization.ipynb 12
def plot_mask(mask, i=0, fig_size=(10,10), title_str="Mask", return_fig=False):
    """
    Plot the mask passed as argument. The mask is a 3D boolean tensor. The first 
    dimension is the window number (or item index), the second is the variable, and the third is the time step.
    Input:
        mask: 3D boolean tensor
        i: index of the window to plot
        fig_size: size of the figure
        title_str: title of the plot
        return_fig: if True, returns the figure
    Output:
        if return_fig is True, returns the figure, otherwise, it does not return anything
    """
    plt.figure(figsize=fig_size)
    plt.pcolormesh(mask[i], cmap='cool')
    plt.title(f'{title_str} {i}, mean: {mask[0].float().mean().item():.3f}')
    if return_fig:
        return plt.gcf()
    else:
        plt.show()
        return None
