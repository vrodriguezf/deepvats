from shiny import App, ui, render
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
import umap 
import plotly.express as px
import plotly.graph_objects as go


# Sample compute umap embeddings function
def compute_umap_embeddings(
    df, 
    n_neighbors=15, 
    min_dist=0.1, 
    n_components=2
):
    reducer = umap.UMAP(
        n_neighbors=n_neighbors, 
        min_dist=min_dist, 
        n_components=n_components
    )
    embeddings = reducer.fit_transform(df[['Value']])
    return embeddings

