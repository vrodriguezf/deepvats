# AUTOGENERATED! DO NOT EDIT! File to edit: nbs/03_dimensionality_reduction.ipynb (unless otherwise specified).

__all__ = ['check_compatibility', 'fget_UMAP_embeddings', 'plot_embeddings']

# Cell
import umap
import pandas as pd
import numpy as np
from fastcore.all import *
from .load import *
from .utils import *

# Cell
def check_compatibility(dr_ar:TSArtifact, dcae_ar:TSArtifact):
    ret = dr_ar.metadata['TS']['vars'] == dcae_ar.metadata['TS']['vars']
    # Check that the dr artifact is not normalized
    return ret

# Cell
import warnings
from numba.core.errors import NumbaPerformanceWarning
@delegates(umap.umap_.UMAP)
def fget_UMAP_embeddings(input_data, **kwargs):
    "Compute the embeddings of `input_data` using UMAP, with a configuration contained in `**kwargs`. \
    Returns also information of the reducer."
    warnings.filterwarnings("ignore", category=NumbaPerformanceWarning) # silence NumbaPerformanceWarning
    reducer = umap.UMAP(**kwargs)
    reducer.fit(input_data)
    embeddings = reducer.transform(input_data)
    return (embeddings, reducer)

# Cell
def plot_embeddings(embeddings):
    "Plot 2D embeddings thorugh a connected scatter plot"
    df_embeddings = pd.DataFrame(embeddings, columns = ['x1', 'x2'])
    fig = plt.figure(figsize=(10,10))
    ax = fig.add_subplot(111)
    ax.scatter(df_embeddings['x1'], df_embeddings['x2'], marker='o', facecolors='none', edgecolors='b', alpha=0.1)
    ax.plot(df_embeddings['x1'], df_embeddings['x2'], alpha=0.5, picker=1)
    return ax

# Cell
# def train_surrogate_model(dcae, embeddings, lat_ln='latent_features'):
#     "Train a surrogate model that learns the `embeddings` from the latent features contained in the layer \
#     `lat_ln` of a previously trained Deep Convolutional AutoEncoder `dcae`"
#     x = dcae.get_layer(lat_ln).output
#     x = Dense(units=embeddings.shape[1], activation='linear')(x)
#     surrogate_model = Model(dcae.input, x)
#     l_nms = [layer.name for layer in surrogate_model.layers]
#     layer_idx = l_nms.index(lat_ln)
#     # The layers that are already trained from the autoencoder must be `frozen`
#     for layer in surrogate_model.layers[:layer_idx]:
#         layer.trainable = False
#     return surrogate_model