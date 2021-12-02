# AUTOGENERATED! DO NOT EDIT! File to edit: nbs/dr.ipynb (unless otherwise specified).

__all__ = ['check_compatibility', 'get_UMAP_prjs']

# Cell
import umap
import cudf
import cuml
import pandas as pd
import numpy as np
from fastcore.all import *
from .imports import *
from .load import TSArtifact

# Cell
def check_compatibility(dr_ar:TSArtifact, enc_ar:TSArtifact):
    "Function to check that the artifact used by the encoder model and the artifact that is \
    going to be passed through the DR are compatible"
    try:
        # Check that both artifacts have the same variables
        chk_vars = dr_ar.metadata['TS']['vars'] == enc_ar.metadata['TS']['vars']
        # Check that both artifacts have the same freq
        chk_freq = dr_ar.metadata['TS']['freq'] == enc_ar.metadata['TS']['freq']
        # Check that the dr artifact is not normalized (not normalized data has not the key normalization)
        chk_norm = dr_ar.metadata['TS'].get('normalization') is None
        # Check that the dr artifact has not missing values
        chk_miss = dr_ar.metadata['TS']['has_missing_values'] == "False"
        # Check all logical vars.
        if chk_vars and chk_freq and chk_norm and chk_miss:
            print("Artifacts are compatible.")
        else:
            raise Exception
    except Exception as e:
        print("Artifacts are not compatible.")
        raise e
    return None

# Cell
import warnings
from numba.core.errors import NumbaPerformanceWarning
@delegates(cuml.UMAP)
def get_UMAP_prjs(input_data, cpu=True, **kwargs):
    "Compute the projections of `input_data` using UMAP, with a configuration contained in `**kwargs`."
    warnings.filterwarnings("ignore", category=NumbaPerformanceWarning) # silence NumbaPerformanceWarning
    reducer = umap.UMAP(**kwargs) if cpu else cuml.UMAP(**kwargs)
    projections = reducer.fit_transform(input_data)
    return projections