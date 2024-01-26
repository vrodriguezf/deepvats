# -*- coding: utf-8 -*-
"""xai.ipynb

Automatically generated.

Original file is located at:
    /home/macu/work/nbs_pipeline/utils_nbs/xai.ipynb
"""

#Basics
import os

#Weight & Biases
import wandb

#Yaml
from yaml import load, FullLoader

#Embeddings
from dvats.all import *
from tsai.data.preparation import prepare_forecasting_data
from tsai.data.validation import get_forecasting_splits
from fastcore.all import *

#Dimensionality reduction
from tsai.imports import *

#Clustering
import hdbscan

import nbs_pipeline.utils.memory as mem
import torch 

def get_prjs(config_dr, check_memory_usage = True, print_flag = False):
    if check_memory_usage:
        gpu_device = torch.cuda.current_device()
        mem.gpu_memory_status(gpu_device)
    #Get W&B API
    api = wandb.Api()
    # Object for storing hyperparameters
    #config_dr = wandb.config
    # Botch to use artifacts offline
    artifacts_gettr = run.use_artifact if config_dr.use_wandb else api.artifact
    # Restore the encoder model and its associated configuration
    enc_artifact = artifacts_gettr(config.enc_artifact, type='learner')
    if print_flag:
        print("--------> Encoder artifact metadata <----------")
        enc_artifact.metadata
        enc_artifact.name

    run_dr = wandb.init(
        entity=config.wandb_entity,
        project=config.wandb_project if config.use_wandb else 'work-nbs', 
        group=config.wandb_group,
        allow_val_change=True, 
        job_type='dimensionality_reduction', 
        mode='online' if config.use_wandb else 'disabled',
        anonymous = 'never' if config.use_wandb else 'must',
        config=config,
        resume = 'allow',
        name = runname
        #resume=False
    )