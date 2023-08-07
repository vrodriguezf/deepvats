import os
import yaml

### Only if !join not defined -- start
def join_constructor(loader, node):
    seq = loader.construct_sequence(node)
    return ''.join(seq)



##### -- end

def get_project_data(print_flag):
    yaml.add_constructor('!join', join_constructor)
    yml_file="base.yaml"
    yml_path="./config/"
    yml=yml_path+yml_file
    current_directory = os.getcwd()
    print("Current: " + current_directory)
    print("yml: "+yml)
    with open(yml, "r") as file:
        config = yaml.load(file, Loader=yaml.FullLoader)

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