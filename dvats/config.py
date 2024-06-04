#!/usr/bin/env python
# coding: utf-8

# In[ ]:


#| default_exp config


# In[ ]:


#| hide
get_ipython().run_line_magic('load_ext', 'autoreload')
get_ipython().run_line_magic('autoreload', '2')


# # Configuration functions 
# > This notebook introduces configuration functions designed to leverage proposed .yaml files, providing a more transparent and automated approach to artefact definition. While this method offers enhanced clarity, the option for direct definition within each notebook is also fully supported and remains practical.
# >
# > <span style="color: red;"> TODO: Check for possible simplifications. </span>

# First, we import
# - os and sys for basic access to files
# - yaml for .yaml reading
# - tsai.basics for using tsai artifacts

# ## Basic configuration and definitions

# In[ ]:


#| export
import os
import yaml
import sys
from tsai.basics import *


# As the yml are saved in ../nbs_pipeline/config, we will need to add '..' path

# In[ ]:


#| export
sys.path.append(os.path.abspath('../nbs_pipeline'))


# In[ ]:


#| export
config_path = os.path.expanduser('~/work/nbs_pipeline/config/')
config_base_filename = 'base'


# An custom_error(message) function is added just for basic error handling

# In[ ]:


#| export
def custom_error(message: str):
    """
    This message raises an exception ensuring red-coloured error message is displayed
    """
    # Change to red color ANSI code
    red_start = "\033[91m"
    # Back to original color ANSI code
    reset = "\033[0m"
    raise Exception(red_start + message + reset)


# ## Yaml reading auxiliar functions
# > Defining basics functions to read yml in order to build Attrdict's
# 
# In the version of YAML we are utilising, the '!join' constructor is not present. Therefore, it becomes necessary to define it.

# In[ ]:


#| export
def join_constructor(loader: yaml.Loader, node: yaml.Node) -> str:
    """
    This function adds the '!join' constructor to the YAML parsing process. 
    It constructs a sequence from the provided node and then joins the elements of the sequence into a single string.
    """
    seq = loader.construct_sequence(node)
    return ''.join(seq)


# In[ ]:


#| export
def recursive_attrdict(d: dict) -> AttrDict:
    """ Recursively converts a dictionary into an AttrDict, including all nested dictionaries. """
    if isinstance(d, dict):
        return AttrDict({k: recursive_attrdict(v) for k, v in d.items()})
    return d


# In[ ]:


#| export
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


# ## Project specific yaml reading functions
# > Basic configuration is read from `../config/base.yml`
# > It contains the following information:
# > - User Preferences: `user_preferences`
# >   - General configuration: `user_preferences`
# >   
# >     | Key         | Description                                             | Example Value |
# >     |-------------|---------------------------------------------------------|---------------|
# >     | `use_wandb` | Indicates whether to use wandb for experiment tracking. | `true`        |
# >   
# >   - Wandb Configuration: `user_preferences.wdb`
# >     
# >     | Key                        | Description                                       | Example Value           |
# >     |----------------------------|---------------------------------------------------|-------------------------|
# >     | `user`                     | The user name for wandb.                          | `mi-santamaria`         |
# >     | `project_name`             | The project name in wandb.                        | `deepvats`              |
# >     | `version`                  | Specifies the version for wandb.                  | `'latest'`              |
# >     | `mode`                     | Sets the mode for wandb.                          | `'offline'`             |
# >     | `artifacts_path`           | The path for storing wandb artifacts.             | `'./data/wandb_artifacts'`|
# >   
# >   - Data configuration: `user_preferences.data`
# >     
# >     | Key                      | Description                                       | Example Value           |
# >     |--------------------------|---------------------------------------------------|-------------------------|
# >     | `folder`                 | The folder where the data is stored.              | `'~/data/'`             |
# >     | `fname`                  | The file name of the dataset used.                | `'solar_4_seconds_dataset'` |
# >     | `ftype`                  | The file type of the dataset.                     | `'.tsf'`                |
# >     | `cols`                   | The columns to be used from the dataset.          | `[]` (all columns)      |
# >     | `freq`                   | The frequency of the dataset.                     | `'4s'`                  |
# >   
# >   - Artifact Configuration: `user_preferences.artifact`
# >     
# >     | Key                      | Description                                       | Example Value           |
# >     |--------------------------|---------------------------------------------------|-------------------------|
# >     | `alias`                  | Alias for the resulting artifact of the run.      | `'solar_4_seconds'`     |
# >     | `algorithm`              | The algorithm used in the process.                | `'mvp'`                 |
# >   
# >   - Directory Configuration: `user_preferences.directories`
# >     
# >     | Key                      | Description                                       | Example Value           |
# >     |--------------------------|---------------------------------------------------|-------------------------|
# >     | `tmp`                    | Folder for storing temporary files.               | `'tmp'`                 |
# >     | `data`                   | Path for the data.                                | Combination of *path, *fname, *ftype |
# >
# > - Data Specifications: `data`
# >   - Data Details: `data`
# >     
# >     | Key                      | Description                                       | Example Value           |
# >     |--------------------------|---------------------------------------------------|-------------------------|
# >     | `name`                   | The name of the data file.                        | Refers to *fname        |
# >     | `path`                   | The path of the data file.                        | Refers to *data_path    |
# >     | `alias`                  | The alias of the data artifact.                   | Refers to *alias        |
# >     | `cols`                   | Columns of interest from the dataset.             | Refers to *cols         |
# >     | `csv_config`             | Configuration for CSV files, if applicable.       | `{}` (if not required)  |
# >     | `date_offset`            | Offset used for setting the date index.           | `null` (if not used)    |
# >     | `date_format`            | Default date format for .tsf files.               | `'%Y-%m-%d %H:%M:%S'`   |
# >     | `freq`                   | Frequency of the data.                            | Refers to *freq         |
# >     | `joining_train_test`     | Linking training and testing data.                | `false`                 |
# >     | `missing_values`         | Handling missing values.                          | `technique: null, constant: null` |
# >     | `normalize_training`     | Indicates whether to normalize training data.     | `false`                 |
# >     | `range_training`         | Specifies training ranges.                        | `null`                  |
# >     | `range_testing`          | Specifies testing ranges.                         | `null`                  |
# >     | `resampling_freq`        | Frequency for resampling the data.                | `null`                  |
# >     | `start_date`             | Starting date for the dataset.                    | `null`                  |
# >     | `test_split`             | Ratio of the test set.                            | `null`                  |
# >     | `time_col`               | Column containing the timestamp.                  | `null`                  |
# >   
# > - Wandb Specifications: `wandb`
# >     
# >     | Key                      | Description                                       | Example Value           |
# >     |--------------------------|---------------------------------------------------|-------------------------|
# >     | `user`                   | User name in wandb specifications.                | Refers to *wdb_user     |
# >     | `dir`                    | Directory for wandb.                              | Combination of '~/', *wdb_project |
# >     | `enabled`                | Indicates if wandb is enabled.                    | `False`                 |
# >     | `group`                  | Group for the wandb runs.                         | `null`                  |
# >     | `log_learner`            | Whether to log the learner to wandb.              | `False`                 |
# >     | `mode`                   | Mode for wandb operation.                         | Refers to *wdb_mode     |
# >     | `project`                | The wandb project name.                           | Refers to *wdb_project  |
# >     | `version`                | Version for the wandb.                            | Refers to *wdb_version  |
# >     | `artifacts_path`         | Path for storing the TSArtifact in wandb.         | Refers to *artifacts_path |
# 

# In[ ]:


#| export

def substitute_env_variables_in_leaves(
    config     : AttrDict, 
    print_flag : bool = False
):   
    if print_flag: print("Config: ", config)
    for key, value in config.items():
        if isinstance(value, str):
            original_value = value
            matches = re.findall(r'\$\{([^}]+)\}', value)
            for match in matches:
                env_value = os.environ.get(match)
                if env_value is not None:
                    value = value.replace('${' + match + '}', env_value)
            config[key] = value
            if print_flag and original_value != value:
                print(f"Changed {key}: from {original_value} to {config[key]}")
        else:
            if isinstance(value, AttrDict):
                substitute_env_variables_in_leaves(value, print_flag)  # Recursividad para diccionarios anidados
    return config


# In[ ]:


#| export
def get_config(
        print_flag: bool = False, 
        filename: str = config_base_filename,
        path = config_path
) -> AttrDict:
    """
    This function 
    - Reads the content in '../config/base.yml' and 
    - Returns its content as AttrDict.
    print_flag option can be changed to True for displaying debugging messages. 
    """
    # Build file path
    if (path[-1] != '/'):
        path += '/'
    filename = filename+".yaml"
    
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
    
    config_attrdict = recursive_attrdict(config)

    substitute_env_variables_in_leaves(
        config = config_attrdict, 
        print_flag = print_flag
    ) 
    return config_attrdict


# In[ ]:


#| hide 
get_config(False)


# ### Build the encoder artifact from already read functions
# > The encoder artifact is needed for training the model.
# > 
# > To automatize its selection, its W&B name is built up from its latest version
# > 
# > <span style="color: red;"> TODO: Change for selecting specific version. Version should be selected in .yml file too </span>.

# In[ ]:


#| export
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


# ### Build project data
# > Read user, project, version and dataset artifact name form already got information

# In[ ]:


#| export
def get_project_data(
    print_flag: bool = False,
    filename=config_base_filename,
    path = config_path
) -> [str, str, str, str]:
    """
    Retrieves project data including user, project name, version, and data name. 
    It accesses configuration settings, processes them, and optionally prints the project configuration. 
    Returns a tuple containing user, project, version, and data information.
    """
    config      = get_config(print_flag = print_flag, filename = filename, path = path)
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


# In[ ]:


#| hide 
get_project_data(False)


# ### Get training artifact name

# In[ ]:


#| export
def get_train_artifact(user: str, project: str, data: str) -> str:
    """
    Constructs the train artifact string by combining user, project, and data information. 
    The format of the return string is 'entity/project/name:version'.
    """
    # entity/project/name:version
    train_artifact=user+'/'+project+'/'+data 
    return train_artifact


# ## Build dataset artifact
# > Configuration file: `base`. Described above.

# ### Auxiliary functions

# In[ ]:


#| export
##############################
# 01 - DATAFRAME TO ARTIFACT #
##############################
def get_artifact_config_sd2a_get_auxiliar_variables(
    print_flag: bool, 
    filename = config_base_filename, 
    path = config_path
) -> Tuple[str, str, str, AttrDict, bool, str]:
    """
    Retrieves auxiliary variables necessary for the dataset artifact configuration. 
    Gathers user, project, version, and data details, along with preferences for using wandb and the wandb artifacts path.
    Returns a tuple containing these elements.
    """
    user, project, version, data = get_project_data(print_flag, filename = filename, path = path)
    config      = get_config(print_flag, filename = filename, path = path)
    data        = config.data
    use_wandb   = config.user_preferences.use_wandb
    wandb_path  = config.wandb.artifacts_path
    return user, project, version, data, use_wandb, wandb_path


# In[ ]:


#| hide
get_artifact_config_sd2a_get_auxiliar_variables(False)


# In[ ]:


#| export
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


# In[ ]:


#| export
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


# ### Main function

# In[ ]:


#| export
def get_artifact_config_sd2a(
    print_flag: bool = False,
    base_filename = config_base_filename,
    path = config_path
) -> AttrDict:
    """
    Constructs the configuration for the dataset artifact by retrieving auxiliary variables and setting up the artifact configuration.
    Validates the configuration to ensure it meets specific criteria and returns the final artifact configuration as an AttrDict.
    """
    user, project, version, data, use_wandb, wandb_path = get_artifact_config_sd2a_get_auxiliar_variables(
        print_flag = print_flag,
        filename = base_filename,
        path = path
    )
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


# In[ ]:


#| hide
get_artifact_config_sd2a(print_flag = False)


# ## Build MVP Encoder artifacts
# > Includes also the versions for sliding window view version
# 
# The configuration files `02b-encoder_mvp` contains the following information:
# ### Configuration for Encoder
# > - General Configuration: `configuration`
# >   
# >   | Key        | Description                                                 | Example Value  |
# >   |------------|-------------------------------------------------------------|----------------|
# >   | `job_type` | The type of job being configured.                           | `'encoder_MVP'`|
# >   | `alias`    | Alias for the configuration, refers to the alias in base.  | Refers to *alias|
# >
# > - Wandb Configuraconfiguration.tion: `wandb`
# >   
# >   | Key        | Description                               | Example Value   |
# >   |------------|-------------------------------------------|-----------------|
# >   | `mode`     | The mode for wandb, inherited from base.  | Refers to *wdb_mode |
# >   | `group`    | Specifies if the run is part of a group.  | `null`           |
# >
# > - Specifications Coconfiguration.nfiguration: `specifications`
# >   
# >   | Key                                      | Description                              | Example Value   |
# >   |------------------------------------------|------------------------------------------|-----------------|
# >   | `batch_size`                             | The batch size for processing.           | `1024`          |
# >   | `n_epoch`                                | Number of epochs for training.           | `100`           |
# >   | `mask.future`                            | Whether to mask future samples.          | `false`         |
# >   | `mask.stateful`                          | Dictates if masking is stateful or not.  | `true`          |
# >   | `mask.sync`                              | Mask all variables at once in series.    | `false`         |
# >   | `mvp.ws1`                                | Min window size for MVP adaptable training. | `15`          |
# >   | `mvp.ws2`                                | Max window size for MVP adaptable training. | `30`          |
# >   | `mvp.r`                                  | Probability of masking in MVP.           | `0.710`         |
# >   | `mvp.valid_size`                         | Size of the validation set proportion.   | `0.2`           |
# >   | `mvp.normalize.by_sample`                | Normalization by sample indicator.       | `false`         |
# >   | `mvp.normalize.use_single_batch`         | Use single batch for normalization.      | `false`         |
# >   | `sliding_windows.stride`                 | Data points the window moves ahead.      | `15`            |
# >   | `sliding_windows.size`                   | Window size for the sliding wiow.      | `30`            |
#  g window.      | `30`            |
# 

# ### Auxiliary functions for retrieving the data

# In[ ]:


#| export
######################
# 02b - ENCODER MVP  #
######################
def get_artifact_config_MVP_auxiliar_variables(
    print_flag    : bool,
    base_filename : str = config_base_filename,
    path          : str = config_path
) -> Tuple[str, str, str, str, AttrDict, str, Tuple[float, float], AttrDict]:
    """
    Retrieves and assembles various configuration parameters and auxiliary variables for an MVP artifact. 
    Extracts user, project, version, and data details, fetches configuration settings, and constructs training artifact strings. 
    Returns a tuple containing these elements along with MVP workspace specifications and user preferences.
    """
    #Get neccesary variables
    user, project, version, data = get_project_data(
        print_flag = print_flag, 
        filename = base_filename,
        path = path
    )
    config          = get_config(
        print_flag, "02b-encoder_mvp"
    )
    user_preferences = config.user_preferences
    config = config.configuration
    train_artifact_ = get_train_artifact(user,project,data)    
    mvp_ws1         = config.specifications.mvp.ws1
    mvp_ws2         = config.specifications.mvp.ws2
    mvp_ws = (mvp_ws1,mvp_ws2)
    return user, project, version, data, config, train_artifact_, mvp_ws, user_preferences


# In[ ]:


#| export
def get_artifact_config_MVP_auxiliar_variables_SWV(
    print_flag      : bool,
    base_filename   : str = config_base_filename,
    path            : str = config_path
) -> Tuple[str, str, str, str, AttrDict, str, Tuple[float, float], AttrDict]:    
    """
    Retrieves and assembles various configuration parameters and auxiliary variables for an MVP artifact. 
    Extracts user, project, version, and data details, fetches configuration settings, and constructs training artifact strings. 
    Returns a tuple containing these elements along with MVP (sliding window view) workspace specifications and user preferences.
    """
    #Get neccesary variables
    user, project, version, data = get_project_data(print_flag, base_filename, path)
    config          = get_config(print_flag, "02c-encoder_mvp-sliding_window_view", path)
    user_preferences = config.user_preferences
    config = config.configuration
    train_artifact_ = get_train_artifact(user,project,data)    
    mvp_ws1         = config.specifications.mvp.ws1
    mvp_ws2         = config.specifications.mvp.ws2
    mvp_ws = (mvp_ws1,mvp_ws2)
    return user, project, version, data, config, train_artifact_, mvp_ws, user_preferences


# In[ ]:


get_artifact_config_MVP_auxiliar_variables_SWV(False)


# ### Auxiliary functions for error handling

# > <span style="color: red;"> TODO: Should we allow diferent project from environment ones? Should we just avoid yml configuration for this parameters and directly get dockers environment WANDB_ENTITIY and WANDB_PROJECT environment variables? </span>.

# In[ ]:


#| export
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


# ### Main configuration functions

# In[ ]:


#| export
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


# In[ ]:


#| export
def get_artifact_config_MVP_SWV(
    print_flag      : bool = False,
    base_filename   : str = config_base_filename,
    path            : str = config_path
) -> Tuple[str, str, str, str, AttrDict, str]:
    """
    Gathers and structures the MVP_SWV artifact configuration, including user, project, version, data details, and various configuration settings.
    Returns a tuple comprising user, project, version, data, the structured artifact configuration as an AttrDict, and the job type.
    """
    user, project, version, data, config, train_artifact_, mvp_ws, user_preferences = get_artifact_config_MVP_auxiliar_variables_SWV(
        print_flag = print_flag,
        base_filename = base_filename,
        path = path
    )

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


# In[ ]:


#| hide
get_artifact_config_MVP_SWV(False)


# ## Encoder DCAE configuration
# > The configuration file `02a-encoder_dcae` contains the following information:
# 
# > - General Configurat: `configuration`ion
# >   
# >   | Key        | Description                                      | Example Value   |
# >   |------------|--------------------------------------------------|-----------------|
# >   | `job_type` | Type of the job for this configuration.           | `'encoder_DCAE'`|
# >   | `alias`    | Alias for the run, referring to the base config.  | Refers to *alias|
# >
# > - Wandb Configconfiguration.uration: `wandb`
# >   
# >   | Key       | Description                                                 | Example Value         |
# >   |-----------|-------------------------------------------------------------|-----------------------|
# >   | `use`     | Indicates whether to use wandb.                             | Refers to *use_wandb  |
# >   | `entity`  | Entity (user) for wandb configuration.                      | Refers to *wdb_user   |
# >   | `group`   | Specifies if this run should be grouped in a wandb group.   | `null`                |
# >   | `project` | Project name for wandb configuration.                       | Refers to *wdb_project|
# >
# > - Artifacconfiguration.ts Configuration: `artifacts`
# >   
# >   | Key             | Description                                                              | Example Value                                         |
# >   |-----------------|--------------------------------------------------------------------------|-------------------------------------------------------|
# >   | `train_prefix`  | Complete training artifact path in wandb.                                | Combination of *wdb_user, *wdb_project, and *alg      |
# >   | `valid.data`    | Complete name for the validation dataset artifact (null for random).     | `null`                                                |
# >   | `valid.size`    | Percentage of random items to go to validation set if `valid.data` is null. | `0.1`                                                 |
# >
# > - Specifications Configuration: `specifications`
# >   
# >   | Key            | Description                                       | Example Value   |
# >   |----------------|---------------------------------------------------|-----------------|
# >   | `batch_size`   | Batch size for processing.                        | `64`            |
# >   | `n_epoch`      | Number of epochs to train for.                    | `200`           |
# >   | `pool_szs`     | Sizes of the pooling layers in the autoencoder.   | `[2,2,4]`       |
# >   | `top_k`        | Number of elements to analyse for the top losses. | `3`             |
# >
# > - Sliding Windows Configuration: `sliding_windows`
# >   
# >   | Key       | Description                             | Example Value |
# >   |-----------|-----------------------------------------|---------------|
# >   | `stride`  | The stride for the sliding window.      | `1`           |
# >   | `size`    | Window size for the sliding window.     | `32`     configuration.     |
# >
# > - Autoencoder Configuration: `autoencoder`
# >   
# >   | Key                 | Description                                                    | Example Value  |
# >   |---------------------|----------------------------------------------------------------|----------------|
# >   | `delta`             | Size of the autoencoder bottleneck layer.                      | `60`           |
# >   | `filters.nfs`       | Number of filters in each convolutional layer of the autoencoder. | `[64,32,16]`   |
# >   | `filters.kss`       | Kernel sizes for each convolutional layer in the autoencoder.  | `[10,5,5]`     |
# >   | `filters.output_size` | The output size of the autoencoder's final layer.             | `10`           |
# inal layer.             | `10`           |
#  | `10`           |
#                   |
# 
# 
# 

# In[ ]:


#| export
######################
# 02a - ENCODER DCAE #
######################

def get_artifact_config_DCAE(
    print_flag: bool = False,
    base_filename = config_base_filename,
    path = config_path
) -> Tuple[AttrDict, str]:
    """
    Constructs the configuration for the DCAE (Deep Convolutional AutoEncoder).
    It fetchs the relevant settings and assembles the artifact configuration.
    Validates the configuration to ensure correct project and entity setup and 
    returns the artifact configuration as an AttrDict along with the job type.
    """
    user, project, version, data = get_project_data(print_flag, base_filename, path)
    config = get_config(print_flag, "02a-encoder_dcae", path)
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
        artifact_config.wandb_entity,
        artifact_config.wandb_project
    )
    return artifact_config, config.job_type


# ## Embeddings configuration
# The specific configurations are in the file `03-embeddings`
# It has the following information:
# 
# > - Job Type: `job_type`
# >   
# >   | Key       | Value         |
# >   |-----------|---------------|
# >   | `job_type`| `'embeddings'`|
# >
# > - Configuration: `configuration`
# >   - Wandb Configuration: `configuration.wandb`
# >   
# >     | Key     | Description                                          | Example Value      |
# >     |---------|------------------------------------------------------|--------------------|
# >     | `group` | Whether to group this run in a wandb group.          | Refers to *emb     |
# >     | `use`   | Indicates whether to use wandb.                      | Refers to *use_wandb |
# >     | `entity`| Entity (user) for wandb configuration.               | Refers to *wdb_user |
# >     | `project`| Project name for wandb configuration.               | Refers to *wdb_project |
# >
# >   - Encoder Configuration: `configuration.encoder`
# >   
# >     | Key                          | Description                                        | Example Value                                   |
# >     |------------------------------|----------------------------------------------------|-------------------------------------------------|
# >     | `artifacts.train.enc_prefix` | Prefix for the training artifacts.                 | Combination of *wdb_user, *wdb_project, and *alg |
# >     | `artifacts.valid`            | If none, the validation set used to train enc is used. | `null`               |
# >
# >   - Specifications Configuration: `configuration.specifications`
# >   
# >     | Key        | Description                                  | Example Value   |
# >     |------------|----------------------------------------------|-----------------|
# >     | `input_ar` | Input array, if applicable.                  | `null`          |
# >     | `cpu`      | Whether to use CPU instead of GPU.           | `false`         |
# 

# In[ ]:


#| export
######################
# 03 - EMBEDDINGS    #
######################
def get_artifact_config_embeddings(
    print_flag  : bool = False,
    config_path : str = config_path
) -> Tuple[AttrDict, str]:
    """
    Constructs the configuration for embeddings by fetching relevant settings and building the encoder artifact configuration.
    Validates the project and entity settings and returns the artifact configuration as an AttrDict, along with the job type.
    """

    config = get_config(print_flag, "03a-embeddings", config_path)
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


# In[ ]:


#| export
def get_artifact_config_embeddings_SWV(
    print_flag      : bool  = False,
    config_path     : str   = config_path
) -> Tuple[AttrDict, str]:
    """
    Constructs the configuration for embeddings (sliding window view) by fetching relevant settings and building the encoder artifact configuration.
    Validates the project and entity settings and returns the artifact configuration as an AttrDict, along with the job type.
    """
    config = get_config(print_flag, "03b-embeddings-sliding_window_view", config_path)
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


# ## Dimensionality Reduction Configuration
# The specific configurations are in the file `04-dimensionality_reduction`
# It contains the following information:
# 
# > - Job Type: `job_type`
# >   
# >   | Key        | Value                      |
# >   |------------|----------------------------|
# >   | `job_type` | `'dimensionality_reduction'`|
# >
# > - Configuration: `configuration`
# >   - Wandb Configuration: `configuration.wandb`
# >   
# >     | Key     | Description                                          | Example Value      |
# >     |---------|------------------------------------------------------|--------------------|
# >     | `use`   | Whether to use wandb for experiment tracking.        | Refers to *use_wandb |
# >     | `group` | Specifies whether to group this run in a wandb group. | `null`            |
# >     | `entity`| The entity to use for wandb.                         | Refers to *wdb_user |
# >     | `project`| The project to use for wandb.                       | Refers to *wdb_project |
# >
# >   - Encoder Configuration: `configuration.encoder`
# >   
# >     | Key                          | Description                                         | Example Value                                   |
# >     |------------------------------|-----------------------------------------------------|-------------------------------------------------|
# >     | `artifacts.train.enc_prefix` | Prefix for the training artifacts.                  | Combination of *wdb_user, *wdb_project, and *alg |
# >     | `artifacts.valid`            | If none, the validation set used to train enc is used. | `null`               |
# >
# >   - UMAP Configuration: `configuration.encoder.umap`
# >   
# >     | Key             | Description                 | Example Value |
# >     |-----------------|-----------------------------|---------------|
# >     | `n_neighbors`   | Number of neighbors for UMAP. | `15`          |
# >     | `min_dist`      | Minimum distance for UMAP.    | `0.1`         |
# >     | `random_state`  | Random state for UMAP.        | `1234`        |
# 
# 

# In[ ]:


#| export
###################################
# 04 - DIMENSIONALITY REDUCTION   #
###################################
def get_artifact_config_dimensionality_reduction(
    print_flag  : bool  = False,
    config_path : str   = config_path
) -> Tuple[AttrDict, str]:
    """
    Constructs the configuration for dimensionality reduction tasks by fetching relevant settings, including building the encoder artifact.
    Returns the artifact configuration as an AttrDict, along with the job type.
    """

    config          = get_config(print_flag, "04-dimensionality_reduction", config_path)
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


# ## XAI - shap reduction configuration
# > <span style="color: red;"> TODO: Not yet implemented or configured... In progress.. </span>
# 
# The specific configurations are in the file `05-xai_shap`
# 

# In[ ]:


#| export
##################
# 05 - XAI-SHAP  #
##################
def get_artifact_config_xai_shap(
    print_flag  : bool  = False,
    config_path : str   = config_path
) -> Tuple[AttrDict, str]:
    """
    Constructs the configuration for the XAI SHAP (Explainable Artificial Intelligence using SHAP values) analysis. 
    This includes fetching relevant settings, building the encoder artifact, and assembling the artifact configuration.
    Returns the artifact configuration as an AttrDict, along with the job type.
    """
    config          = get_config(print_flag, "05-xai_shap", config_path)
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


# In[ ]:


#| hide -> Not yet implemented
#get_artifact_config_xai_shap(False)


# ## Use a tested configuration

# [Monash benchmark](https://huggingface.co/datasets/monash_tsf) datasets used configurations

# In[ ]:


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


# In[ ]:


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


# In[ ]:


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


# [Wikipedia web traffic dataset](https://zenodo.org/records/3898474)

# In[ ]:


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


# [Traffic San Francisco](https://zenodo.org/records/3898445)

# In[ ]:


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


# In[ ]:


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


# ### Other public datasets

# #### Electricity Transformer Temperature
# [ETDataset](https://paperswithcode.com/dataset/ett)

# In[ ]:


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


# #### Stumpy
# ##### [Semantic segmentation TitlABP](https://stumpy.readthedocs.io/en/latest/Tutorial_Semantic_Segmentation.html)

# In[ ]:


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


# ##### [Multi-dimensional toy data](https://zenodo.org/records/4294932)

# In[ ]:


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
        stride = 1
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


# ### Get tested configuration function

# In[ ]:


#| export
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


# In[ ]:


#| export
def show_attrdict(dict: AttrDict):
    for key, value in dict.items():
        print(f"{key}: {value}")


# In[ ]:


#| export
def show_available_configs():
    print("Available datasets: ")
    i = 0
    for key, val in tested_configs.items():
        print(f"{i} - {key}")
        i+=1
    


# In[ ]:


#| hide 
show_available_configs()


# In[ ]:


#| hide 
list(tested_configs.items())[3][0]


# In[ ]:


#| export
def show_config(id: int = 0):
    show_attrdict(list(tested_configs.items())[id][1])


# In[ ]:


#| hide
show_config(3)


# In[ ]:


#| export
def get_tested_config(
    id: int = 0,
    print_flag=False
):
    if print_flag: show_config(id)
    return list(tested_configs.items())[id][1]
    


# In[ ]:


#| hide
show_attrdict(get_tested_config(0))


# ### Force tested configuration functions
# #### 01 - Dataset Artifact

# In[ ]:


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


# In[ ]:


#| export
import pandas as pd


# In[ ]:


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


# In[ ]:


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


# In[ ]:


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


# In[ ]:


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


# In[ ]:


#| hide
sd2a_config = AttrDict(
    artifact_name= "Monash-Australian_electricity",
    csv_config= {},
    data_cols= [0],
    data_fpath= '~/data/australian_electricity_demand_dataset.csv',
    date_format= '%Y-%m-%d %H:%M:%S',
    date_offset= None,
    freq= '1s',
    joining_train_test= False,
    missing_values_constant= None,
    missing_values_technique= None,
    normalize_training= False,
    range_testing= None,
    range_training= None,
    resampling_freq= None,
    start_date= None,
    test_split= None,
    time_col= None,
    use_wandb= True,
    wandb_artifacts_path='./data/wandb_artifacts'
)


# In[ ]:


#| hide
force_artifact_config_sd2a(
    config = sd2a_config, 
    id = 6, 
    print_flag=True, 
    both=True, 
    frequency_factor = 2, 
    frequency_factor_change_alias = True
)


# #### 02(bc) Encoder MVP

# In[ ]:


#| export
def split_artifact_string(s:string) -> tuple[string, string, string]:
    # Divide la cadena en dos partes usando ':'
    path, version = s.split(':')

    # Divide la parte del path en sus componentes
    parts = path.rsplit('/', 1)

    # Retorna los componentes separados
    return parts[0] + '/', parts[1], version


# In[ ]:


#| hide
result = split_artifact_string("mi-santamaria/deepvats/Monash-Australian_electricity_demand:latest")
print(result)


# In[ ]:


#| export 
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


# In[ ]:


#| hide
mvp_config = AttrDict(
    alias = "Monash-Australian_electric",
    artifact_name="Monash-Australian_electricity",
    analysis_mode="online",
    batch_size=2,
    epochs=1,
    mask_future=False,
    mask_stateful=True,
    mask_sync=False,
    mvp_ws=(150, 33),
    norm_by_sample=False,
    norm_use_single_batch=False,
    r=0.71,
    stride=13,
    train_artifact="mi-santamaria/deepvats/Monash-Australian_electricity_demand:latest",
    valid_artifact=None,
    use_wandb=True,
    valid_size=0.2,
    w=30,
    wandb_group=None,
    data_cols= [],
    data_fpath= "~/data/kaggle_web_traffic_dataset_with_missing_values.tsf",
    freq= '1d',
    time_col= 'None'
)


# In[ ]:


#| hide 
force_artifact_config_mvp(mvp_config, 1, True, True, 5, True)


# In[ ]:


#| export 
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


# In[ ]:


#| hide
dcae_config = AttrDict(
    alias = "Monash-Australian_electric",
    artifact_name="Monash-Australian_electricity",
    analysis_mode="online",
    batch_size=2,
    epochs=1,
    r=0,
    stride=1,
    train_artifact="mi-santamaria/deepvats/Monash-Australian_electricity_demand:latest",
    valid_artifact=None,
    use_wandb=True,
    valid_size=0.2,
    w=30,
    nfs = [],
    kss = [], 
    output_filter_size = 1,
    top_k = [],
    delta = 6,
    wandb_group=None,
    data_cols= [],
    data_fpath= "~/data/kaggle_web_traffic_dataset_with_missing_values.tsf",
    freq= '1d',
    time_col= 'None'
)


# In[ ]:


#| hide 
force_artifact_config_dcae(dcae_config, 1, True, True, 5, True)

