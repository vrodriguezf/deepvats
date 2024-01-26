# -*- coding: utf-8 -*-
"""config.ipynb

Automatically generated.

Original file is located at:
    /home/macu/work/nbs_pipeline/utils_nbs/config.ipynb
"""

import os
import yaml
import sys
from tsai.basics import *

sys.path.append(os.path.abspath('..'))

def custom_error(message: str):
    """
    This message raises an exception ensuring red-coloured error message is displayed
    """
    # Change to red color ANSI code
    red_start = "\033[91m"
    # Back to original color ANSI code
    reset = "\033[0m"
    raise Exception(red_start + message + reset)

def join_constructor(loader: yaml.Loader, node: yaml.Node) -> str:
    """
    This function adds the '!join' constructor to the YAML parsing process. 
    It constructs a sequence from the provided node and then joins the elements of the sequence into a single string.
    """
    seq = loader.construct_sequence(node)
    return ''.join(seq)

def recursive_attrdict(d: dict) -> AttrDict:
    """ Recursively converts a dictionary into an AttrDict, including all nested dictionaries. """
    if isinstance(d, dict):
        return AttrDict({k: recursive_attrdict(v) for k, v in d.items()})
    return d

def replace_includes_with_content(
    filename: str, 
    path: str = "./", 
    print_flag: bool = False
) -> str:
    """
    This function processes a YAML file.
    It replaces '!include' directives with the content of the specified files. 
    It takes a filename and a path, reads the file, and iteratively replaces any '!include' directives with the content of the included files.
    The final processed content, with all '!include' directives substituted is returned as a string.
    """
    if (print_flag):
        print("... About to replace includes with content")
    with open(path+filename, 'r') as f:
        content = f.read()

        # Mientras exista una directiva !include en el contenido, sigue reemplazándola
        while "!include" in content:
            # Obtén la posición de la directiva
            start_idx = content.find('!include')
            # Encuentra el inicio y el final de las comillas que contienen el nombre del archivo
            start_quote_idx = content.find('"', start_idx) + 1
            end_quote_idx = content.find('"', start_quote_idx)

            # Extrae el nombre del archivo
            include_filename = content[start_quote_idx:end_quote_idx]

            # Lee el archivo incluido
            with open(path+include_filename, 'r') as include_file:
                included_content = include_file.read()

            # Reemplaza la directiva por el contenido del archivo incluido
            content = content[:start_idx] + included_content + content[end_quote_idx+1:]

    return content

def get_config(
        print_flag: bool = False, 
        filename: str = "base"
) -> AttrDict:
    """
    This function 
    - Reads the content in '../config/base.yml' and 
    - Returns its content as AttrDict.
    print_flag option can be changed to True for displaying debugging messages. 
    """
    # Build file path
    filename = filename+".yaml"
    path = "./config/"
    # Debug messages
    if (print_flag):
        current_directory = os.getcwd()
        print("Current: " + current_directory)
        print("yml: "+ path + filename)

    # Add join constructor
    yaml.add_constructor('!join', join_constructor)

    if (print_flag): 
        print("Getting content"+ path + filename)

    # Get file content
    full_content = replace_includes_with_content(filename, path, print_flag)

    if (print_flag):
        print("Load content"+ path + filename)

    # Load content 
    config = yaml.load(full_content, Loader=yaml.FullLoader)

    # Return content it as AttrDict
    return recursive_attrdict(config)

def build_enc_artifact(
    config: AttrDict, 
    print_flag: bool = False
) -> str:
    """
    Build enc_artifact name from config data.
    """
    version = config.user_preferences.wdb.version
    enc_artifact = config.configuration.encoder.artifacts.train.enc_prefix
    if (version == 'latest'):
        enc_artifact+=":latest"
    else:
        enc_artifact=enc_artifact+":v"+version
    if (print_flag):
        print("enc_artifact: "+enc_artifact)
    return enc_artifact

def get_project_data(print_flag: bool = False) -> [str, str, str, str]:
    """
    Retrieves project data including user, project name, version, and data name. 
    It accesses configuration settings, processes them, and optionally prints the project configuration. 
    Returns a tuple containing user, project, version, and data information.
    """
    config      = get_config()
    project     = config.wandb.project
    user        = config.wandb.user
    version     = config.wandb.version
    data_name   = config.data.alias
    if (version != "latest"):
        version = 'v' +version
    data        = data_name +":"+version
    if print_flag:
        dashes = '-----------'        
        print(dashes+"Project configuration"+dashes)
        print("user: " + user)
        print("project: " + project)
        print("version: " + version)
        print("data: "+ data)
        print(dashes+"Project configuration"+dashes)
    return user, project, version, data

def get_train_artifact(user: str, project: str, data: str) -> str:
    """
    Constructs the train artifact string by combining user, project, and data information. 
    The format of the return string is 'entity/project/name:version'.
    """
    # entity/project/name:version
    train_artifact=user+'/'+project+'/'+data 
    return train_artifact

##############################
# 01 - DATAFRAME TO ARTIFACT #
##############################
def get_artifact_config_sd2a_get_auxiliar_variables(print_flag: bool) -> Tuple[str, str, str, AttrDict, bool, str]:
    """
    Retrieves auxiliary variables necessary for the dataset artifact configuration. 
    Gathers user, project, version, and data details, along with preferences for using wandb and the wandb artifacts path.
    Returns a tuple containing these elements.
    """
    user, project, version, data = get_project_data(print_flag)
    config      = get_config(print_flag)
    data        = config.data
    use_wandb   = config.user_preferences.use_wandb
    wandb_path  = config.wandb.artifacts_path
    return user, project, version, data, use_wandb, wandb_path

def get_artifact_config_sd2a_check_errors(use_wandb: str, artifact_config: AttrDict, user: str, project: str):
    """
    Checks for configuration errors in the dataset artifact settings. 
    Verifies the project and entity, and ensures appropriate settings are made for offline mode and missing values handling.
    """
    check_project_and_entity(user, project)
    if (
            use_wandb   == "offline" 
        and artifact_config.joining_train_test  == True
    ):
        custom_error("If you're using deepvats in offline mode, set joining_train_test to False")
    if (
            artifact_config.missing_values_constant is not None 
        and artifact_config.missing_values_technique is None
    ):
        custom_error("Missing values constant must be setted up only if missing_values_technique is not None. Please check base.yaml")

def get_artifact_config_sd2a(print_flag: bool = False) -> AttrDict:
    """
    Constructs the configuration for the dataset artifact by retrieving auxiliary variables and setting up the artifact configuration.
    Validates the configuration to ensure it meets specific criteria and returns the final artifact configuration as an AttrDict.
    """
    user, project, version, data, use_wandb, wandb_path = get_artifact_config_sd2a_get_auxiliar_variables(print_flag)
    artifact_config = AttrDict(
        artifact_name           = data.alias,
        csv_config              = data.csv_config,
        data_cols               = data.cols,
        data_fpath              = data.path,
        date_format             = data.date_format,
        date_offset             = data.date_offset,
        freq                    = data.freq,
        joining_train_test      = data.joining_train_test,
        missing_values_technique= data.missing_values.technique,
        missing_values_constant = data.missing_values.constant,
        normalize_training      = data.normalize_training,
        range_training          = data.range_training,
        range_testing           = data.range_testing,
        resampling_freq         = data.resampling_freq,
        start_date              = data.start_date,
        test_split              = data.test_split,
        time_col                = data.time_col,
        use_wandb               = use_wandb,
        wandb_artifacts_path    = wandb_path
    )
    get_artifact_config_sd2a_check_errors(use_wandb, artifact_config, user, project)    
    return artifact_config

######################
# 02b - ENCODER MVP  #
######################
def get_artifact_config_MVP_auxiliar_variables(print_flag: bool) -> Tuple[str, str, str, str, AttrDict, str, Tuple[float, float], AttrDict]:
    """
    Retrieves and assembles various configuration parameters and auxiliary variables for an MVP artifact. 
    Extracts user, project, version, and data details, fetches configuration settings, and constructs training artifact strings. 
    Returns a tuple containing these elements along with MVP workspace specifications and user preferences.
    """

    #Get neccesary variables
    user, project, version, data = get_project_data(print_flag)
    config          = get_config(print_flag, "02b-encoder_mvp")
    user_preferences = config.user_preferences
    config = config.configuration
    train_artifact_ = get_train_artifact(user,project,data)    
    mvp_ws1         = config.specifications.mvp.ws1
    mvp_ws2         = config.specifications.mvp.ws2
    mvp_ws = (mvp_ws1,mvp_ws2)
    return user, project, version, data, config, train_artifact_, mvp_ws, user_preferences

def get_artifact_config_MVP_auxiliar_variables_SWV(print_flag: bool) -> Tuple[str, str, str, str, AttrDict, str, Tuple[float, float], AttrDict]:    
    """
    Retrieves and assembles various configuration parameters and auxiliary variables for an MVP artifact. 
    Extracts user, project, version, and data details, fetches configuration settings, and constructs training artifact strings. 
    Returns a tuple containing these elements along with MVP (sliding window view) workspace specifications and user preferences.
    """
    #Get neccesary variables
    user, project, version, data = get_project_data(print_flag)
    config          = get_config(print_flag, "02c-encoder_mvp-sliding_window_view")
    user_preferences = config.user_preferences
    config = config.configuration
    train_artifact_ = get_train_artifact(user,project,data)    
    mvp_ws1         = config.specifications.mvp.ws1
    mvp_ws2         = config.specifications.mvp.ws2
    mvp_ws = (mvp_ws1,mvp_ws2)
    return user, project, version, data, config, train_artifact_, mvp_ws, user_preferences

def check_project_and_entity(user: str, project: str):
    """
    Checks user and project are correctly setted up comparing to environment variables
    """
    os_entity = os.environ['WANDB_ENTITY']
    os_project = os.environ['WANDB_PROJECT']
    if (os_entity != user):
        custom_error("Please check .env and base.yml: entity != user os " + os_entity + " yaml " + user)
    if (os_project != project):
        custom_error("Please check .env and base.yml: project differs os " + os_project + " yaml " + project)

def get_artifact_config_MVP_check_errors(
    artifact_config: AttrDict, 
    user: str, 
    project: str 
):
    """
    Avoids incompatible wandb modes configurations.
    Sets project = 'work-nbs' if wandb is not used for tracking.
    """
    check_project_and_entity(user, project)

    if artifact_config.use_wandb:
        if (artifact_config.analysis_mode != 'online'):
            print("Changing to online analysis mode - use_wandb=true")
            artifact_config.analysis_mode = 'online'
    else:
        project = 'work-nbs'

def get_artifact_config_MVP(print_flag: bool = False) -> Tuple[str, str, str, str, AttrDict, str]:
    """
    Gathers and structures the MVP artifact configuration, including user, project, version, data details, and various configuration settings.
    Returns a tuple comprising user, project, version, data, the structured artifact configuration as an AttrDict, and the job type.
    """
    user, project, version, data, config, train_artifact_, mvp_ws, user_preferences = get_artifact_config_MVP_auxiliar_variables(print_flag)

    artifact_config = AttrDict(
        alias                   = config.alias,
        analysis_mode           = config.wandb.mode, 
        batch_size              = config.specifications.batch_size,
        epochs                  = config.specifications.n_epoch,
        mask_future             = config.specifications.mask.future,
        mask_stateful           = config.specifications.mask.stateful,
        mask_sync               = config.specifications.mask.sync,
        mvp_ws                  = mvp_ws, 
        norm_by_sample          = config.specifications.mvp.normalize.by_sample,
        norm_use_single_batch   = config.specifications.mvp.normalize.use_single_batch,
        r                       = config.specifications.mvp.r,
        stride                  = config.specifications.sliding_windows.stride, 
        train_artifact          = train_artifact_, 
        valid_artifact          = None, 
        use_wandb               = user_preferences.use_wandb, 
        valid_size              = config.specifications.mvp.valid_size,
        w                       = config.specifications.sliding_windows.size, 
        wandb_group             = config.wandb.group
    )
    get_artifact_config_MVP_check_errors(artifact_config, user, project)
    return user, project, version, data, artifact_config, config.job_type

def get_artifact_config_MVP_SWV(print_flag: bool = False) -> Tuple[str, str, str, str, AttrDict, str]:
    """
    Gathers and structures the MVP_SWV artifact configuration, including user, project, version, data details, and various configuration settings.
    Returns a tuple comprising user, project, version, data, the structured artifact configuration as an AttrDict, and the job type.
    """
    user, project, version, data, config, train_artifact_, mvp_ws, user_preferences = get_artifact_config_MVP_auxiliar_variables_SWV(print_flag)

    artifact_config = AttrDict(
        alias                   = config.alias,
        analysis_mode           = config.wandb.mode, 
        batch_size              = config.specifications.batch_size,
        epochs                  = config.specifications.n_epoch,
        mask_future             = config.specifications.mask.future,
        mask_stateful           = config.specifications.mask.stateful,
        mask_sync               = config.specifications.mask.sync,
        mvp_ws                  = mvp_ws, 
        norm_by_sample          = config.specifications.mvp.normalize.by_sample,
        norm_use_single_batch   = config.specifications.mvp.normalize.use_single_batch,
        r                       = config.specifications.mvp.r,
        stride                  = config.specifications.sliding_windows.stride, 
        train_artifact          = train_artifact_, 
        valid_artifact          = None, 
        use_wandb               = user_preferences.use_wandb, 
        valid_size              = config.specifications.mvp.valid_size,
        w                       = config.specifications.sliding_windows.size, 
        wandb_group             = config.wandb.group
    )
    get_artifact_config_MVP_check_errors(artifact_config, user, project)
    return user, project, version, data, artifact_config, config.job_type

######################
# 02a - ENCODER DCAE #
######################

def get_artifact_config_DCAE(print_flag: bool = False) -> Tuple[AttrDict, str]:
    """
    Constructs the configuration for the DCAE (Deep Convolutional AutoEncoder).
    It fetchs the relevant settings and assembles the artifact configuration.
    Validates the configuration to ensure correct project and entity setup and 
    returns the artifact configuration as an AttrDict along with the job type.
    """
    user, project, version, data = get_project_data(print_flag)
    config = get_config(print_flag, "02a-encoder_dcae")
    if print_flag: print("Antes de leer configuration " + str(config))
    config = config.configuration

    artifact_config = AttrDict(
        alias               = config.alias,
        use_wandb           = config.wandb.use,
        wandb_group         = config.wandb.group,
        wandb_entity        = config.wandb.entity,
        wandb_project       = config.wandb.project,
        train_artifact      = get_train_artifact(user,project,data),
        valid_artifact      = config.artifacts.valid.data,
        valid_size          = config.artifacts.valid.size,
        w                   = config.specifications.sliding_windows.size,
        stride              = config.specifications.sliding_windows.stride,
        delta               = config.specifications.autoencoder.delta,
        nfs                 = config.specifications.autoencoder.filters.nfs,
        kss                 = config.specifications.autoencoder.filters.kss,
        output_filter_size  = config.specifications.autoencoder.filters.output_size,
        pool_szs            = config.specifications.pool_szs,
        batch_size          = config.specifications.batch_size, 
        epochs              = config.specifications.n_epoch,
        top_k               = config.specifications.pool_szs
    )
    check_project_and_entity(
        artifact_config.wandb_entity, artifact_config.wandb_project
    )
    return artifact_config, config.job_type

######################
# 03 - EMBEDDINGS    #
######################
def get_artifact_config_embeddings(print_flag: bool = False) -> Tuple[AttrDict, str]:
    """
    Constructs the configuration for embeddings by fetching relevant settings and building the encoder artifact configuration.
    Validates the project and entity settings and returns the artifact configuration as an AttrDict, along with the job type.
    """

    config = get_config(print_flag, "03a-embeddings")
    job_type=config.job_type
    version = config.user_preferences.wdb.version
    enc_artifact = build_enc_artifact(config, print_flag)
    config = config.configuration
    artifact_config = AttrDict(
        use_wandb       = config.wandb.use,
        wandb_group     = config.wandb.group,
        wandb_entity    = config.wandb.entity,
        wandb_project   = config.wandb.project,
        enc_artifact    = enc_artifact,
        input_ar        = config.specifications.input_ar,
        cpu             = config.specifications.cpu
    )
    check_project_and_entity(artifact_config.wandb_entity, artifact_config.wandb_project)
    return artifact_config, job_type

def get_artifact_config_embeddings_SWV(print_flag: bool = False) -> Tuple[AttrDict, str]:
    """
    Constructs the configuration for embeddings (sliding window view) by fetching relevant settings and building the encoder artifact configuration.
    Validates the project and entity settings and returns the artifact configuration as an AttrDict, along with the job type.
    """
    config = get_config(print_flag, "03b-embeddings-sliding_window_view")
    job_type=config.job_type
    version = config.user_preferences.wdb.version
    enc_artifact = build_enc_artifact(config, print_flag)
    config = config.configuration
    artifact_config = AttrDict(
        use_wandb       = config.wandb.use,
        wandb_group     = config.wandb.group,
        wandb_entity    = config.wandb.entity,
        wandb_project   = config.wandb.project,
        enc_artifact    = enc_artifact,
        input_ar        = config.specifications.input_ar,
        cpu             = config.specifications.cpu
    )
    check_project_and_entity(artifact_config.wandb_entity, artifact_config.wandb_project)
    return artifact_config, job_type

###################################
# 04 - DIMENSIONALITY REDUCTION   #
###################################
def get_artifact_config_dimensionality_reduction(print_flag: bool = False) -> Tuple[AttrDict, str]:
    """
    Constructs the configuration for dimensionality reduction tasks by fetching relevant settings, including building the encoder artifact.
    Returns the artifact configuration as an AttrDict, along with the job type.
    """

    config          = get_config(print_flag, "04-dimensionality_reduction")
    job_type        = config.job_type
    enc_artifact = build_enc_artifact(config, print_flag)
    config = config.configuration
    artifact_config = AttrDict(
        use_wandb           = config.wandb.use, 
        wandb_group         = config.wandb.group,
        wandb_entity        = config.wandb.entity,
        wandb_project       = config.wandb.project,
        valid_artifact      = config.encoder.artifacts.valid, 
        train_artifact      = enc_artifact,
        n_neighbors         = config.encoder.umap.n_neighbors,
        min_dist            = config.encoder.umap.min_dist,
        random_state        = config.encoder.umap.random_state
    )
    return artifact_config, job_type

##################
# 05 - XAI-SHAP  #
##################
def get_artifact_config_xai_shap(print_flag: bool = False) -> Tuple[AttrDict, str]:
    """
    Constructs the configuration for the XAI SHAP (Explainable Artificial Intelligence using SHAP values) analysis. 
    This includes fetching relevant settings, building the encoder artifact, and assembling the artifact configuration.
    Returns the artifact configuration as an AttrDict, along with the job type.
    """
    config          = get_config(print_flag, "05-xai_shap")
    job_type        = config.job_type
    enc_artifact = build_enc_artifact(config, print_flag)
    config = config.configuration
    artifact_config = AttrDict(
        use_wandb           = config.wandb.use, 
        wandb_group         = config.wandb.group,
        wandb_entity        = config.wandb.entity,
        wandb_project       = config.wandb.project,
        valid_artifact      = config.encoder.artifacts.valid, 
        train_artifact      = enc_artifact,
        n_neighbors         = config.encoder.umap.n_neighbors,
        min_dist            = config.encoder.umap.min_dist,
        random_state        = config.encoder.umap.random_state
    )
    return artifact_config, job_type

#| export
# Monash australian electricity demand
monash_australian_electricity_demand_0 = AttrDict(
    alias ="Monash-Australian_electricity_demand",
    fname ="australian_electricity_demand_dataset",
    #5 univariate timeseries. 0-4 can be used 1 each time
    cols =[0],
    ftype ='.tsf',
    freq ='30min', 
    time_col = None,
    mvp = AttrDict(
        batch_size = 512,
        n_epoch = 100,
        ws = [2,336], #1h-1week | TODO: Check to ensure freq sense
        stride = 48 #Day2Day TODO: Check
    ),
    dcae = AttrDict(#TODO: Check
        batch_size = 512,
        n_epoch = 100,
        stride = 48,
        w      = 224,
        delta  = 60,
        nfs    = [64, 32, 16],
        kss     = [10, 5, 5],
        output_filter_size = 10,
        top_k = [2,2,4],
        pool_szs = [2,2,4]
    )
)

#| export
# Monash sunspot:
monash_sunspot_0 = AttrDict(
    alias = "sunspot",
    fname = "sunspot_dataset_with_missing_values",
    ftype = ".tsf",
    cols = [],
    freq ='1d',
    time_col = None,
    mvp = AttrDict(
        batch_size = 512,
        n_epoch = 100,
        ws = [7,365], #1week-1year
        stride = 30 #1 month TODO: Check
    ),
    dcae = AttrDict(#TODO: Check
        batch_size = 512,
        n_epoch = 100,
        stride = 48,
        w      = 224,
        delta  = 60,
        nfs    = [64, 32, 16],
        kss     = [10, 5, 5],
        output_filter_size = 10,
        top_k = [2,2,4],
        pool_szs = [2,2,4]
    )
)

#| export
monash_solar_4_seconds_0 = AttrDict(
    alias =  'solar_4_seconds',
    fname = 'solar_4_seconds_dataset',
    ftype = '.tsf',
    freq = '4s',
    cols = [],
    time_col= None,
    mvp = AttrDict(
        batch_size = 512,
        n_epoch = 100,
        #1 4 seconds
        #15 1 min
        #450 30 min - Too small for G4-0
        #900 1h
        ws = [450,900], #1 min - 30 min (15*60=900 = 1hora intervalos 4 secs)
        stride = 450
        #stride = 10800 #1 min TODO: Check
    ),
    dcae = AttrDict(#TODO: Check
        batch_size = 512,
        n_epoch = 100,
        stride = 48,
        w      = 224,
        delta  = 60,
        nfs    = [64, 32, 16],
        kss     = [10, 5, 5],
        output_filter_size = 10,
        top_k = [2,2,4],
        pool_szs = [2,2,4]
    )
)

#| export
wikipedia_0 = AttrDict(
    alias="Wikipedia",
    fname="kaggle_web_traffic_dataset_with_missing_values",
    cols=[0, 1, 2, 3, 4],
    ftype=".tsf",
    freq = '1d',
    time_col=None,
    mvp = AttrDict(
        batch_size = 512,
        n_epoch = 100,
        ws = [1,365], #1d-1año
        stride = 1 #TODO: Check
    ),
    dcae = AttrDict(#TODO: Check
        batch_size = 512,
        n_epoch = 100,
        stride = 48,
        w      = 224,
        delta  = 60,
        nfs    = [64, 32, 16],
        kss     = [10, 5, 5],
        output_filter_size = 10,
        top_k = [2,2,4],
        pool_szs = [2,2,4]
    )
)

#| export
traffic_san_francisco_0 = AttrDict(
    alias="Traffic_SF",
    fname="traffic_hourly_dataset",
    ftype=".tsf",
    cols=[],
    time_col=None,
    freq='1h',
    mvp = AttrDict(
        batch_size = 512,
        n_epoch = 100,
        ws = [1,720], #1h-1week TODO: Check
        stride = 24 #1 day TODO: Check
    ),
    dcae = AttrDict(#TODO: Check
        batch_size = 512,
        n_epoch = 100,
        stride = 48,
        w      = 224,
        delta  = 60,
        nfs    = [64, 32, 16],
        kss     = [10, 5, 5],
        output_filter_size = 10,
        top_k = [2,2,4],
        pool_szs = [2,2,4]
    )
)

#| export
# Monash solar 10 minutes dataset
# Multi-dimensional
monash_solar_10_minutes_0 = AttrDict(
    alias ="Monash-Solar_10_minutes",
    fname ="solar_10_minutes_dataset",
    #5 univariate timeseries. 0-4 can be used 1 each time
    #137 columns (each one 1 different timeserie)
    cols =[0],
    ftype ='.tsf',
    freq ='10min',
    time_col = None,
    mvp = AttrDict(
        batch_size = 512,
        n_epoch = 100,
        #1 month 4320 -> Too big for G4 (GPU-0)
        #1 day 144 -> Ok
        #1 week 1008 -> Ok
        #15 days 2160 -> Ok
        ws = [1,2160],
        stride = 144 #1d by 1d
    ),
    dcae = AttrDict(#TODO: Check
        batch_size = 512,
        n_epoch = 100,
        stride = 48,
        w      = 224,
        delta  = 60,
        nfs    = [64, 32, 16],
        kss     = [10, 5, 5],
        output_filter_size = 10,
        top_k = [2,2,4],
        pool_szs = [2,2,4]
    )
)

#| export
etth1_0 = AttrDict(
    alias="ETTh1",
    fname="ETTh1",
    ftype=".csv",
    cols=[],
    time_col=0,
    freq='1h',
    mvp = AttrDict(
        batch_size = 512,
        n_epoch = 100,
        ws = [1,720], #1 h - 1 month TODO:Check
        stride = 24 #1 day TODO: Check
    ),
    dcae = AttrDict(#TODO: Check
        batch_size = 512,
        n_epoch = 100,
        stride = 48,
        w      = 224,
        delta  = 60,
        nfs    = [64, 32, 16],
        kss     = [10, 5, 5],
        output_filter_size = 10,
        top_k = [2,2,4],
        pool_szs = [2,2,4]
    )
)

#| export
stumpy_abp_0 = AttrDict(
    alias="TitlABP",
    fname="Semantic_Segmentation_TiltABP",
    ftype=".csv",
    cols=[],
    freq="1s",
    time_col=0, 
    mvp = AttrDict(
        batch_size = 512,
        n_epoch = 100,
        ws = [60,3600], #1min-1h TODO:Check
        stride = 60 #1 min TODO: Check
    ),
    dcae = AttrDict(#TODO: Check
        batch_size = 512,
        n_epoch = 100,
        stride = 48,
        w      = 224,
        delta  = 60,
        nfs    = [64, 32, 16],
        kss     = [10, 5, 5],
        output_filter_size = 10,
        top_k = [2,2,4],
        pool_szs = [2,2,4]
    )
)

#| export
stumpy_toy_0 = AttrDict(
    alias="toy",
    fname="toy",
    ftype=".csv",
    cols=[],
    freq="1s",
    time_col=None,
    mvp = AttrDict(
        batch_size = 512,
        n_epoch = 100,
        ws = [10,30], 
        stride = 5
    ),
    dcae = AttrDict(#TODO: Check
        batch_size = 512,
        n_epoch = 100,
        stride = 48,
        w      = 224,
        delta  = 60,
        nfs    = [64, 32, 16],
        kss     = [10, 5, 5],
        output_filter_size = 10,
        top_k = [2,2,4],
        pool_szs = [2,2,4]
    )
)

tested_configs = {
    'monash_australian_electricity_demand_0': monash_australian_electricity_demand_0,
    'monash_solar_4_seconds_0': monash_solar_4_seconds_0,
    'wikipedia_0': wikipedia_0,
    'traffic_san_francisco_0': traffic_san_francisco_0,
    'monash_solar_10_minutes_0': monash_solar_10_minutes_0,
    'etth1_0': etth1_0,
    'stumpy_abp_0':  stumpy_abp_0,
    'stumpy_toy_0': stumpy_toy_0
}

#| export
def show_attrdict(dict: AttrDict):
    for key, value in dict.items():
        print(f"{key}: {value}")

#| export
def show_available_configs():
    print("Available datasets: ")
    i = 0
    for key, val in tested_configs.items():
        print(f"{i} - {key}")
        i+=1


#| export
def show_config(id: int = 0):
    show_attrdict(list(tested_configs.items())[id][1])

#| export
def get_tested_config(
    id: int = 0,
    print_flag=False
):
    if print_flag: show_config(id)
    return list(tested_configs.items())[id][1]


#| export
def print_colored(
    key, 
    modified_val, 
    modified, 
    both:bool=False, 
    original_val=0,
    missing_in_modified=False,
    missing_in_original=False
):
    if missing_in_modified:
        color = "\033[91m\033[1m"  # Red and bold
    elif missing_in_original:
        color = "\033[93m\033[1m"  # Orange and bold
    else:
        color = "\033[94m" if modified else ""
    reset = "\033[0m"

    if modified and both:
        print(f"{color}{key}: {original_val}{reset} -> {modified_val}{reset}")
    elif missing_in_modified:
        print(f"{color}{key} is missing in modified dict | {original_val} {reset}")
    elif missing_in_original:
        print(f"{color}{key} is missing in original dict | {modified_val} {reset}")
    else:
        print(f"{color}{key}: {modified_val}{reset}")

import pandas as pd

#| export 
def get_resampling_frequency(
    freq: str,
    frequency_factor:int = 1,
    print_flag = False
):
    if print_flag:
        print("--> Frequency factor resampling frequency")
        print("Freq factor: ", frequency_factor)
    freq_new = pd.to_timedelta(freq)
    freq_new = freq_new*frequency_factor
    if print_flag:
        print("freq_original: ", freq)
        print("freq_new: ", freq_new)
    suffix = "-"
    resampling_freq=""
    if freq_new.days > 0 and freq_new.seconds == pd.to_timedelta(0,'s'):
        suffix  = str(freq_new.days)+'d'
        resampling_freq = str(freq_new.days)+'D'
    elif freq_new.seconds % 3600 == 0:
        hours = (freq_new.seconds // 3600) + freq_new.days*24
        suffix = str(hours)+'h'
        resampling_freq = str(hours) + 'H'
    elif freq_new.seconds % 60 == 0: 
        minutes = (freq_new.seconds // 60) + (freq_new.days*24*60)
        suffix = str(minutes)+'m'
        resampling_freq = str(minutes)+'T'
    else: 
        seconds = freq_new.seconds + freq_new.days*24*60*60 
        suffix = str(seconds)+'s'
        resampling_freq = str(seconds)+'S'
    if print_flag:
        print("suffix: ", suffix)
        print("resampling_freq: ", resampling_freq)
        print("Frequency factor resampling frequency -->")
    return (suffix, resampling_freq)

#| export
def frequency_factor_config(
    config: AttrDict, 
    frequency_factor:int = 1,
    frequency_factor_change_alias: bool = True,
    print_flag = False
):
    if print_flag:
        print("--> Frequency factor config")
        print("Freq factor: ", frequency_factor)
        print("frequency_factor_change_alias: ", frequency_factor_change_alias)
    suffix, config.resampling_freq = get_resampling_frequency(config.freq, frequency_factor, print_flag)

    if frequency_factor_change_alias:
        #filename = config.data_fpath.split(".tsf", 1)[0]
        config.artifact_name = config.artifact_name+"-"+suffix
        #config.data_fpath = filename+"-"+suffix+".tsf"

    if print_flag:     
        print("resampling_freq: ", config.freq)
        print("name: ", config.artifact_name)
        print("path: ", config.data_fpath)    
        print("Frequency factor config -->")

#| export
def diff_attrdict(
    dict_original: AttrDict, 
    dict_modified: AttrDict,
    both: bool = False
):
    all_keys = set(dict_original.keys()) | set(dict_modified.keys())
    for key in all_keys:
        in_original = key in dict_original
        in_modified = key in dict_modified

        if in_original and in_modified:
            modified = dict_original[key] != dict_modified[key]
            print_colored(
                key, 
                modified_val = dict_modified[key], 
                modified = modified, 
                both = both, 
                original_val=dict_original[key]
            )
        elif in_original:
            # Key is missing in dict_modified
            print_colored(key, modified_val=None, modified=True, missing_in_modified=True)
        else:
            # Key is missing in dict_original
            print_colored(key, modified_val=dict_modified[key], modified=True, missing_in_original=True)

#| export
from copy import deepcopy
def force_artifact_config_sd2a(
    config: AttrDict,
    id:int = 0, 
    print_flag = False,
    both = False,
    frequency_factor = 1, 
    frequency_factor_change_alias = True
):
    to_set = get_tested_config(id)
    if print_flag: 
        config_before = deepcopy(config)
        print("Selecting ", list(tested_configs.items())[id][0])
    config.artifact_name = to_set.alias
    config.data_cols = to_set.cols
    config.data_fpath= "~/data/"+to_set.fname+to_set.ftype
    config.freq=to_set.freq
    config.time_col = to_set.time_col
    config.csv_config = {}
    joining_train_test= False,
    missing_values_constant= None,
    missing_values_technique= None,
    normalize_training= False,
    range_testing= None,
    range_training= None,
    resampling_freq= None,
    start_date= None,
    test_split= None,
    if frequency_factor > 1: 
        frequency_factor_config(config, frequency_factor, frequency_factor_change_alias, print_flag)
    if print_flag: 
        diff_attrdict(
            dict_original=config_before, 
            dict_modified=config, 
            both = both)

#| export
def split_artifact_string(s:string) -> tuple[string, string, string]:
    # Divide la cadena en dos partes usando ':'
    path, version = s.split(':')

    # Divide la parte del path en sus componentes
    parts = path.rsplit('/', 1)

    # Retorna los componentes separados
    return parts[0] + '/', parts[1], version

#| Export 
def force_artifact_config_mvp(
    config: AttrDict,
    id:int = 0, 
    print_flag = False,
    both = False,
    frequency_factor = 1,
    frequency_factor_change_alias = False,
):
    to_set = get_tested_config(id)
    if print_flag: 
        config_before = deepcopy(config)

    force_artifact_config_sd2a(
        config = config, 
        id = id, 
        print_flag = False, 
        both = False, 
        frequency_factor = frequency_factor, 
        frequency_factor_change_alias = frequency_factor_change_alias
    )

    config.alias = to_set.alias
    config.batch_size = to_set.mvp.batch_size
    config.epochs = to_set.mvp.n_epoch

    config.mask_future = False 
    config.mask_stateful = True
    config.mask_sync = False
    config.norm_by_sample = False
    config.norm_use_by_single_batch = False,
    config.r = 0.71

    config.stride=to_set.mvp.stride
    path,_,version = split_artifact_string(config.train_artifact)
    config.train_artifact=path+config.artifact_name+":"+version

    config.valid_size = 0.2

    config.mvp_ws= to_set.mvp.ws
    config.w = config.mvp_ws[1]

    if print_flag: 
        diff_attrdict(
            dict_original=config_before, 
            dict_modified=config, 
            both = both
        )

#| Export 
def force_artifact_config_dcae(
    config: AttrDict,
    id:int = 0, 
    print_flag = False,
    both = False,
    frequency_factor = 1,
    frequency_factor_change_alias = False,
):
    to_set = get_tested_config(id)
    if print_flag: 
        config_before = deepcopy(config)

    force_artifact_config_sd2a(
        config = config, 
        id = id, 
        print_flag = False, 
        both = False, 
        frequency_factor = frequency_factor, 
        frequency_factor_change_alias = frequency_factor_change_alias
    )

    config.alias = to_set.alias

    config.batch_size = to_set.dcae.batch_size
    config.epochs = to_set.dcae.n_epoch    
    config.r = 0.71
    config.stride=to_set.dcae.stride
    path,_,version = split_artifact_string(config.train_artifact)
    config.train_artifact=path+config.artifact_name+":"+version

    config.valid_size = 0.2
    config.w = to_set.dcae.w
    config.delta = to_set.dcae.delta
    config.nfs = to_set.dcae.nfs
    config.kss = to_set.dcae.kss
    config.output_filter_size = to_set.dcae.kss
    config.top_k = to_set.dcae.top_k
    config.pool_szs = to_set.dcae.pool_szs

    if print_flag: 
        diff_attrdict(
            dict_original=config_before, 
            dict_modified=config, 
            both = both
        )