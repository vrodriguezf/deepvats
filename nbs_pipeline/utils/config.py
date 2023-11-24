import os
import yaml
import sys
from tsai.basics import *
sys.path.append(os.path.abspath('..'))


### Only if !join not defined -- start
def join_constructor(loader, node):
    seq = loader.construct_sequence(node)
    return ''.join(seq)
##### -- end

def custom_error(message):
    # Código ANSI para texto en rojo
    red_start = "\033[91m"
    # Código ANSI para restablecer el color
    reset = "\033[0m"
    raise Exception(red_start + message + reset)


def recursive_attrdict(d):
    """ Recursively converts a dictionary into an AttrDict, including all nested dictionaries. """
    if isinstance(d, dict):
        return AttrDict({k: recursive_attrdict(v) for k, v in d.items()})
    return d

def replace_includes_with_content(filename, path = "./", print_flag = False):
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

def get_config(print_flag=False, filename="base"):
    filename = filename+".yaml"
    path = "./config/"
    if (print_flag):
        current_directory = os.getcwd()
        print("Current: " + current_directory)
        print("yml: "+ path + filename)
    yaml.add_constructor('!join', join_constructor)
    if (print_flag): 
        print("Getting content"+ path + filename)
    full_content = replace_includes_with_content(filename, path, print_flag)
    if (print_flag):
        print("Load content"+ path + filename)
    config = yaml.load(full_content, Loader=yaml.FullLoader)
    return recursive_attrdict(config)

def build_enc_artifact(config, print_flag = False):
    version = config.user_preferences.wdb.version
    enc_artifact = config.configuration.encoder.artifacts.train.enc_prefix
    if (version == 'latest'):
        enc_artifact+=":latest"
    else:
        enc_artifact=enc_artifact+":v"+version
    if (print_flag):
        print("enc_artifact: "+enc_artifact)
    return enc_artifact

def get_project_data(print_flag):
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

def get_train_artifact(user, project, data):
    # entity/project/name:version
    train_artifact=user+'/'+project+'/'+data 
    return train_artifact

#MVP ENCODER
def get_artifact_config_MVP_auxiliar_variables(print_flag):
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

def get_artifact_config_MVP_auxiliar_variables_SWV(print_flag):
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

def check_project_and_entity(user, project):
    os_entity = os.environ['WANDB_ENTITY']
    os_project = os.environ['WANDB_PROJECT']
    if (os_entity != user):
        custom_error("Please check .env and base.yml: entity != user os " + os_entity + " yaml " + user)
    if (os_project != project):
        custom_error("Please check .env and base.yml: project differs os " + os_project + " yaml " + project)


def get_artifact_config_MVP_check_errors(artifact_config, user, project):
    check_project_and_entity(user, project)
        
    if artifact_config.use_wandb:
        if (artifact_config.analysis_mode != 'online'):
            print("Changing to online analysis mode - use_wandb=true")
            artifact_config.analysis_mode = 'online'
    else:
        project = 'work-nbs'

def get_artifact_config_MVP(print_flag=False):
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

def get_artifact_config_MVP_SWV(print_flag=False):
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

##############################
# 01 - DATAFRAME TO ARTIFACT #
##############################
def get__artifact_config_sd2a_get_auxiliar_variables(print_flag):
    user, project, version, data = get_project_data(print_flag)
    config      = get_config(print_flag)
    data        = config.data
    use_wandb   = config.user_preferences.use_wandb
    wandb_path  = config.wandb.artifacts_path
    return user, project, version, data, use_wandb, wandb_path

def get__artifact_config_sd2a_check_errors(use_wandb, artifact_config, user, project):
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

def get_artifact_config_sd2a(print_flag=False):
    user, project, version, data, use_wandb, wandb_path = get__artifact_config_sd2a_get_auxiliar_variables(print_flag)
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
    get__artifact_config_sd2a_check_errors(use_wandb, artifact_config, user, project)    
    return artifact_config

######################
# 02a - ENCODER DCAE #
######################
def get_artifact_config_DCAE(print_flag=False):
    config = get_config(print_flag, "02a-encoder_dcae")
    print("Antes de leer configuration " + str(config))
    enc_artifact = build_enc_artifact(config, print_flag)
    config = config.configuration
    artifact_config = AttrDict(
        use_wandb           = config.wandb.use,
        wandb_group         = config.wandb.group,
        wandb_entity        = config.wandb.entity,
        wandb_project       = config.wandb.project,
        train_artifact      = enc_artifact,
        valid_artifact      = config.artifacts.valid.data,
        # In case valid_artifact is None, this will set the percentage of random items to go to val
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
    check_project_and_entity(artifact_config.wandb_entity, artifact_config.wandb_project)
    return artifact_config, config.job_type


######################
# 03 - EMBEDDINGS    #
######################
def get_artifact_config_embeddings(print_flag=False):
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


def get_artifact_config_embeddings_SWV(print_flag=False):
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
def get_artifact_config_dimensionality_reduction(print_flag=False):
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
def get_artifact_config_xai_shap(print_flag=False):
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