# -*- coding: utf-8 -*-
"""01_dataset_artifact.ipynb

Automatically generated.

Original file is located at:
    /home/macu/work/nbs_pipeline/01_dataset_artifact.ipynb
"""

#| export
import sys
import dvats.utils as ut
if '--vscode' in sys.argv:
    print("Executing inside vscode")
    ut.DisplayHandle.update = ut.update_patch

#| export
print_flag = False

#| export
import dvats.config as cfg_

#| export 
# This cell is for instrumental code. Use the next cell for real final configuration for this notebook
pre_configured_case = False
case_id = None
frequency_factor = 1
frequency_factor_change_alias = True

#| export
import pandas as pd
import numpy as np
from fastcore.all import *
import wandb
from dvats.load import TSArtifact, infer_or_inject_freq
import pickle
import matplotlib
import matplotlib.pyplot as plt
from tsai.data.external import convert_tsf_to_dataframe
from tsai.utils import stack_pad

#| export
base_path = Path.home()

#| export
config = cfg_.get_artifact_config_sd2a(print_flag = False)
if pre_configured_case: 
    cfg_.force_artifact_config_sd2a(
        config = config, 
        id = case_id, 
        print_flag = print_flag, 
        both = print_flag, 
        frequency_factor = frequency_factor, 
        frequency_factor_change_alias = frequency_factor_change_alias
    )

#| export
ext = str(config.data_fpath).split('.')[-1]

if ext == 'pickle':
    df = pd.read_pickle(config.data_fpath)

elif ext in ['csv','txt']:
    df = pd.read_csv(config.data_fpath, **config.csv_config)

elif ext == 'tsf':
    data, _, _, _, _ = convert_tsf_to_dataframe(os.path.expanduser(config.data_fpath))
    config.update({'start_date': data.start_timestamp[0]}, allow_val_change=True)
    date_format = config.date_format
    df = pd.DataFrame(stack_pad(data.series_value).T)

else:
    raise Exception('The data file path has an unsupported extension')

#| export
if config.time_col is not None:
    if print_flag: print("time_col: "+str(config.time_col))

    if isinstance(config.time_col, int): 
        if print_flag: print("Op 1: time_col int")
        datetime = df.iloc[:, config.time_col]

    elif isinstance(config.time_col, list): 
        if print_flag: print("Op 2: time_col list")
        datetime = df.iloc[:, config.time_col].apply(lambda x: x.astype(str).str.cat(sep='-'), axis=1)

    index = pd.DatetimeIndex(datetime)

    if config.date_offset:
        index += config.date_offset

    df = df.set_index(index, drop=False)   

    #Delete Timestamp col
    col_name = df.columns[config.time_col]

    if print_flag: print("... drop Timestamp col " + str(col_name))

    df = df.drop(col_name, axis=1)

if print_flag: display(df.head())

#| export
df = infer_or_inject_freq(
    df, 
    injected_freq=config.freq, 
    start_date=config.start_date, 
    format=config.date_format
)
if print_flag: print(df.index.freq)

#| export
# Subset of variables
if config.data_cols:
    if print_flag: print("data_cols: ", config.data_cols)
    df = df.iloc[:, config.data_cols]

if print_flag: print(f'Num. variables: {len(df.columns)}')

#| export
# Replace the default missing values by np.NaN
if config.missing_values_constant:
    df.replace(config.missing_values_constant, np.nan, inplace=True)

#| export
rg = config.range_training

if isinstance(rg, list):
    rg_training = rg

elif isinstance(rg, dict):
    rg_training = pd.date_range(rg['start'], rg['end'], freq=rg['freq'])

elif config.test_split:
    rg_training = df.index[:math.ceil(len(df) * (1-config.test_split))]

else:
    rg_training = None

df_training = df[df.index.isin(rg_training)] if rg_training is not None else df

#| export
training_artifact = TSArtifact.from_df(
    df_training, 
    name=config.artifact_name, 
    missing_values_technique=config.missing_values_technique,
    resampling_freq=config.resampling_freq, 
    normalize=config.normalize_training, 
    path=str(Path.home()/config.wandb_artifacts_path)
)
if print_flag: display(training_artifact.metadata)

#| export
#Debugging 
if df_training.index.duplicated().any():
    raise ValueError("Duplicated index names")

#| export
# Testing data
rg = config.range_testing

if rg or config.test_split:

    if isinstance(rg, list):
        rg_testing = rg

    elif isinstance(rg, dict):
        rg_testing = pd.date_range(rg['start'], rg['end'], freq=rg['freq'])

    elif config.test_split:
        rg_testing = df.index[math.ceil(len(df) * (1 - config.test_split)):]

    else:
        rg_testing = None

    df_testing = df[df.index.isin(rg_testing)]
    testing_artifact = TSArtifact.from_df(df_testing,
                                          name=config.artifact_name, 
                                          missing_values_technique=config.missing_values_technique,
                                          resampling_freq=config.resampling_freq, 
                                          normalize=False,
                                          path=str(Path.home()/config.wandb_artifacts_path))
    display(testing_artifact.metadata)
    if df_testing.index.duplicated().any():
        print("There exist duplicated value(s) in the index dataframe.")
    else:
        if print_flag: print("There is no duplicated value in the index dataframe.")
else:
    if print_flag: print("rg "+ str(rg) + " | test_split "+ str(config.test_split))
    testing_artifact = None

#| export
# Training + Testing data
if(config.joining_train_test):
    print("joining_train_test: "+ str(config.joining_train_test))
    df_train_test = pd.concat([df_training, df_testing])
    train_test_artifact = TSArtifact.from_df(
        df_train_test,
        name=config.artifact_name, 
        missing_values_technique=config.missing_values_technique,
        resampling_freq=config.resampling_freq, 
        normalize=False,
        path=str(Path.home()/config.wandb_artifacts_path)
    )
    if df_train_test.index.duplicated().any():
        print("There exist duplicated value(s) within the dataframe index.")
    else:
        if print_flag: print("There is no duplicated value in the dtaframe index")
    if print_flag: display(train_test_artifact.metadata)
else:
    train_test_artifact = None

#| export
import os
path = os.path.expanduser("~/work/nbs_pipeline/")
name="01_dataset_artifact"
os.environ["WANDB_NOTEBOOK_NAME"] = path+name+".ipynb"
runname=name
print("runname: "+runname)

#| export
mode = 'online' if config.use_wandb else 'disabled'

# Make the run that will produce the artifact
with wandb.init(job_type='create_dataset', resume=True, mode=mode, config=config, name=runname) as run:
    if testing_artifact: 
        run.log_artifact(training_artifact, aliases=['train'])
        run.log_artifact(testing_artifact, aliases=['test'])

        if train_test_artifact:
            run.log_artifact(train_test_artifact, aliases=['all'])

    else:
        run.log_artifact(training_artifact, aliases=['all'])

#| export
run.finish()

#| export
from dvats.imports import beep
print("Execution ended")
beep(1)