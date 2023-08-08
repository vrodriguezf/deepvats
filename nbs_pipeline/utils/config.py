import utils.errors
import os
import yaml
import sys
sys.path.append(os.path.abspath('..'))
from tsai.basics import *

### Only if !join not defined -- start
def join_constructor(loader, node):
    seq = loader.construct_sequence(node)
    return ''.join(seq)
##### -- end

def get_config(print_flag=False):
    yaml.add_constructor('!join', join_constructor)
    yml_path="./config/base.yaml"
    yml=="./config/"
    if (print_flag):
        current_directory = os.getcwd()
        print("Current: " + current_directory)
        print("yml: "+yml)
    with open(yml, "r") as file:
        config = AtrrDict(yaml.load(file, Loader=yaml.FullLoader))
    return config

def get_project_data(print_flag):
    config      = get_config()
    project     = config.wandb.project
    user        = config.wandb.user
    version     = config.wandb.version
    data_name   = config.data.name
    data        = data_name + ':v' +version
    if print_flag:
        dashes = '-----------'        
        print(dashes+"Project configuration"+dashes)
        print("user: " + user)
        print("project: " + project)
        print("version: " + version)
        print("data: "+ data)
        print(dashes+"Project configuration"+dashes)
    return user, project, version, data

def get_train_artifact(user, project, data):
    # entity/project/name:version
    train_artifact=user+'/'+project+'/'+data 
    return train_artifact

#MVP ENCODER
def get_artifact_config_MVP_auxiliar_variables():
    #Get neccesary variables
    user, project, version, data = get_project_data(print_flag)
    config          = get_config()
    train_artifact_ = get_train_artifact(user,project,data)
    artifact        = config.artifact_MVP
    mvp_ws1         = artifact.mvp_ws1
    mvp_ws2         = artifact.mvp_ws2
    mvp_ws = (mvp_ws1,mvp_ws2)
    return user, project, version, data, config, train_artifact_, mvp_ws

def get_artifact_config_MVP_check_errors(artifact_config):
    os_entity = os.environ['WANDB_ENTITY']
    os_project = os.environ['WANDB_PROJECT']
    if (os_entity != user):
        custom_error("Please check .env and base.yml: entity != user os " + os_entity + " yaml " + user)
    if (os_project != project):
        custom_error("Please check .env and base.yml: project differs os " + os_project + " yaml " + project)
        
    if artifact_config.use_wandb:
        if (artifact_config.analysis_mode != 'online'):
            print("Changing to online analysis mode - use_wandb=true")
            artifact_config.analysis_mode = 'online'
    else:
        project = 'work-nbs'

def get_artifact_config_MVP(print_flag=False):
    user, project, version, data, config, train_artifact_, mvp_ws = get_artifact_config_MVP_auxiliar_variables()
    artifact_config = AttrDict(
        alias                   = artifact.alias,
        analysis_mode           = config.wandb.mode, 
        batch_size              = artifact.batch_size,
        epochs                  = artifact.n_epoch,
        mask_future             = bool(artifact.mask_future),
        mask_stateful           = bool(artifact.mask_stateful),
        mask_sync               = bool(artifact.mask_sync),
        mvp_ws                  = mvp_ws, 
        norm_by_sample          = artifact.norm_by_sample,
        norm_use_single_batch   = artifact.norm_use_single_batch,
        r                       = artifact.r,
        stride                  = artifact.stride, 
        train_artifact          = train_artifact_, 
        use_wandb               = config.user_preferences.use_wandb, 
        valid_size              = artifact.valid_size,
        w                       = artifact.w,
        wandb_group             = artifact.wandb_group
    )
    get_artifact_config_MVP_check_errors(artifact_config)
    return user, project, version, data, artifact_config

#DATAFRAME TO ARTIFACT
def get__artifact_config_sd2a_get_auxiliar_variables():
    user, project, version, data = get_project_data(print_flag)
    config      = get_config()
    data        = config.data
    use_wandb   = config.wandb.use_wandb
    wandb_path  = config.user_preferences.wandb_artifacts_path
    return user, project, version, data, use_wandb, wandb_path

def get__artifact_config_sd2a_check_errors(use_wandb, artifact_config):
    if (
            use_wandb   == "offline" 
        and artifact_config.joining_train_test  == True
    ):
        custom_error("If you're using deepvats in offline mode, set joining_train_test to False")
    if (
            artifact_config.missing_values.constant is not None 
        and artifact_config.missing_values.technique is None
    ):
        custom_error("Missing values constant must be setted up only if missing_values_technique is not None. Please check base.yaml")

def get_artifact_config_sd2a(print_flag=False):
    user, project, version, data, use_wandb, wandb_path = get__artifact_config_sd2a_get_auxiliar_variables()
    artifact_config = AttrDict(
        artifact_name           = data.alias,
        csv_config              = data.csv_config,
        data_cols               = data.cols,
        data_fpath              = data.path,
        date_format             = data.date_format,
        date_offset             = data.date_offset,
        freq                    = data.freq,
        joining_train_test      = bool(data.joining_train_test),
        missing_values          = AtrrDict(
                                    technique   = data.missing_values.technique,
                                    constant    = data.missing_values.constant,
                                )
        normalize_training      = data.normalize_training,
        range_training          = data.range_training,
        range_testing           = data.range_testing,
        resampling_freq         = data.resampling_freq,
        start_date              = data.start_date,
        test_split              = data.test_split,
        time_col                = data.time_col,
        use_wandb               = use_wandb
        wandb_artifacts_path    = wandb_path
    )
    get__artifact_config_sd2a_check_errors(use_wandb, artifact_config)    
    return artifact_config