import utils.errors
import os
import yaml
import sys
sys.path.append(os.path.abspath('..'))
#from dvats.all import *
#from fastcore.all import *
from tsai.basics import *
#from tsai.models.InceptionTimePlus import *
#from tsai.callback.MVP import *
#import matplotlib.colors as colors
#from fastai.callback.wandb import WandbCallback
#from fastai.callback.progress import ShowGraphCallback
#from fastai.callback.schedule import *
#import wandb
#wandb_api = wandb.Api()

### Only if !join not defined -- start
def join_constructor(loader, node):
    seq = loader.construct_sequence(node)
    return ''.join(seq)



##### -- end
def get_config(print_flag=False):
    yaml.add_constructor('!join', join_constructor)
    yml_file="base.yaml"
    yml_path="./config/"
    yml=yml_path+yml_file
    if (print_flag):
        current_directory = os.getcwd()
        print("Current: " + current_directory)
        print("yml: "+yml)
    with open(yml, "r") as file:
        config = yaml.load(file, Loader=yaml.FullLoader)
    return config

def get_project_data(print_flag):
    config=get_config()
    project=config['wandb']['project']
    user=config['wandb']['user']
    version=config['wandb']['version']
    data_name=config['data']['name']
    data = data_name + ':v' +version
    if print_flag:
        dashes = '-----------'
        
        print(dashes+"Project configuration"+dashes)
        print("user: " + user)
        print("project: " + project)
        print("version: " + version)
        print("data: "+ data)
        print(dashes+"Project configuration"+dashes)
      
    return user, project, version, data

def get_train_artiffact(user, project, data):
    # entity/project/name:version
    train_artiffact=user+'/'+project+'/'+data 
    return train_artiffact

def get_artiffact_config_MVP(print_flag=False):
    user, project, version, data = get_project_data(print_flag)
    config = get_config()
    train_artiffact_=get_train_artiffact(user,project,data)
    artiffact=config['artiffact_MVP']
    mvp_ws1=artiffact['mvp_ws1']
    mvp_ws2=artiffact['mvp_ws2']
    artiffact_config = AttrDict(
        alias = artiffact['alias'],
        analysis_mode = config['wandb']['mode'], 
        batch_size = artiffact['batch_size'],
        epochs = artiffact['n_epoch'],
        mask_futures = bool(artiffact['mask_futures']),
        mask_stateful =  bool(artiffact['mask_stateful']),
        mask_sync=bool(artiffact['mask_sync']),
        mvp_ws = (mvp_ws1, mvp_ws2), 
        norm_by_sample = artiffact['norm_by_sample'],
        norm_use_single_batch=artiffact['norm_use_single_batch'],
        r = artiffact['r'],
        stride = artiffact['stride'], 
        train_artifact = train_artiffact_, 
        use_wandb=artiffact['use_wandb'], 
        valid_size = artiffact['valid_size'],
        w = artiffact['w'],
        wandb_group = artiffact['wandb_group']
    )
    os_entity = os.environ['WANDB_ENTITY']
    os_project = os.environ['WANDB_PROJECT']
    if (os_entity != user):
        custom_error("Please check .env and base.yml: entity != user os " + os_entity + " yaml " + user)
    if (os_project != project):
        custom_error("Please check .env and base.yml: project differs os " + os_project + " yaml " + project)
        
    if not artiffact_config.use_wandb:
        project = 'work-nbs'
    return user, project, version, data, artiffact_config

