# Standard
import os
import math
import tempfile
import torch

# Third Party
from torch.optim import AdamW
from torch.optim.lr_scheduler import OneCycleLR
from transformers import EarlyStoppingCallback, Trainer, TrainingArguments, set_seed
import numpy as np
import pandas as pd

# tsfm library
from tsfm_public import (
    TimeSeriesPreprocessor,
    TinyTimeMixerForPrediction,
    TrackingCallback,
    count_parameters
)
from tsfm_public.toolkit.visualization import plot_predictions

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
import dvats.config as cfg_

def load_from_config_df_base(
        verbose = 0,
        pre_configured_case = True,
        case_id = 7,
        frequency_factor = 1,
        frequency_factor_change_alias = True
):
    config = cfg_.get_artifact_config_sd2a(verbose = 0)
    if pre_configured_case: 
        if verbose > 0: print(f"Pre configured case id: {case_id}")
        cfg_.force_artifact_config_sd2a(
            config = config, 
            id = case_id, 
            verbose = verbose, 
            both = verbose > 0, 
            frequency_factor = frequency_factor, 
            frequency_factor_change_alias = frequency_factor_change_alias
        )
    if verbose > 0: cfg_.show_attrdict(config)
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
    if config.time_col is not None:
        if verbose > 0: print("time_col: "+str(config.time_col))
    
        if isinstance(config.time_col, int): 
            if verbose > 0: print("Op 1: time_col int")
            datetime = df.iloc[:, config.time_col]
    
        elif isinstance(config.time_col, list): 
            if verbose > 0: print("Op 2: time_col list")
            datetime = df.iloc[:, config.time_col].apply(lambda x: x.astype(str).str.cat(sep='-'), axis=1)
    
        index = pd.DatetimeIndex(datetime)
    
        if config.date_offset:
            index += config.date_offset
    
        df = df.set_index(index, drop=False)   
    
        #Delete Timestamp col
        col_name = df.columns[config.time_col]
    
        if verbose > 0: print("... drop Timestamp col " + str(col_name))
    
        df = df.drop(col_name, axis=1)
    
    if verbose > 0: display(df.head())
    return df, config

def load_from_config(
    verbose = 0,
    show_plots = False,
    pre_configured_case = True,
    case_id = 7,
    frequency_factor = 1,
    frequency_factor_change_alias = True
):
    df, config = load_from_config_df_base(verbose, show_plots, pre_configured_case, case_id, frequency_factor, frequency_factor_change_alias)
    
    df = infer_or_inject_freq(
        df, 
        injected_freq=config.freq, 
        start_date=config.start_date, 
        format=config.date_format
    )
    if verbose > 0: print(df.index.freq)
    # Subset of variables
    if config.data_cols:
        if verbose > 0: print("data_cols: ", config.data_cols)
        df = df.iloc[:, config.data_cols]
    if verbose > 0: print(f'Num. variables: {len(df.columns)}')
    # Replace the default missing values by np.NaN
    if config.missing_values_constant:
        df.replace(config.missing_values_constant, np.nan, inplace=True)
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
            if verbose > 0: print("There is no duplicated value in the index dataframe.")
    else:
        if verbose > 0: print("rg "+ str(rg) + " | test_split "+ str(config.test_split))
        testing_artifact = None

        


# Define data loaders using TSP from the tsfm library
def get_data(
    dataset_name: str,
    context_length,
    forecast_length,
    fewshot_fraction=1.0,
    use_config = True,
    config_map = {
        "venice": {
            #"dataset_path": "https://raw.githubusercontent.com/matteorinalduzzi/TTM/main/datasets/venice/venice_small.csv",
            "dataset_path": "datasets/venice/venice_small.csv",
            "timestamp_column": "DATE",
            "id_columns": [],
            "target_columns": ["LEVEL"],
            "control_columns": ["PRESS"], 
            "split_config": {
                "train": 0.7,
                #"valid": 0.1,
                "test": 0.2,
            },
        },
    },
    verbose = 0
):
    if verbose > 0:
        print(dataset_name, context_length, forecast_length)

    
    if dataset_name not in config_map.keys():
        raise ValueError(
            f"Currently `get_data()` function supports the following datasets: {config_map.keys()}\n \
                         For other datasets, please provide the proper configs to the TimeSeriesPreprocessor (TSP) module."
        )

    dataset_path = config_map[dataset_name]["dataset_path"]
    timestamp_column = config_map[dataset_name]["timestamp_column"]
    id_columns = config_map[dataset_name]["id_columns"]
    target_columns = config_map[dataset_name]["target_columns"]
    split_config = config_map[dataset_name]["split_config"]
    control_columns = config_map[dataset_name]["control_columns"]

    if not use_config:
        if target_columns == []:
            df_tmp_ = pd.read_csv(dataset_path)
            target_columns = list(df_tmp_.columns)
            if (timestamp_column != ""):
                target_columns.remove(timestamp_column)

        data = pd.read_csv(
            dataset_path,
            parse_dates=[timestamp_column],
        )

        column_specifiers = {
            "timestamp_column": timestamp_column,
            "id_columns": id_columns,
            "target_columns": target_columns,
            "control_columns": control_columns,    
        }
    else: 
        load_from_config(verbose = verbose, pre_configured_case = False)    
    
    tsp = TimeSeriesPreprocessor(
        **column_specifiers,
        context_length=context_length,
        prediction_length=forecast_length,
        scaling=True,
        encode_categorical=False,
        scaler_type="standard",
    )

    train_dataset, valid_dataset, test_dataset = tsp.get_datasets(
        data, split_config, fewshot_fraction=fewshot_fraction, fewshot_location="first"
    )
    print(f"Data lengths: train = {len(train_dataset)}, val = {len(valid_dataset)}, test = {len(test_dataset)}")

    return train_dataset, valid_dataset, test_dataset