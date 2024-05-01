#!/bin/bash --login
set -e
#echo $ENV_PREFIX
#conda list 
ls -la /home/$USER/work
pip install -e /home/$USER/work

echo $WANDB_ENTITY $USER $WANDB_PROJECT

### Ensuring to activate the correct conda
source /usr/local/share/miniconda3/etc/profile.d/conda.sh
conda activate /usr/local/share/miniconda3/envs/env
#Check
conda list | grep wandb
###

#!/bin/bash

############################
# Extra pre-commit options #
############################

########## Fix base.yaml for ensuring correct user & project directly ########## [TODO: Remove this section for directly using .env option]
line_found=$(grep "^[[:space:]]*user: &wdb_user" /home/$USER/work/nbs_pipeline/config/base.yaml)

if [ -z "$line_found" ]; then
    echo "User line not found."
    exit 1
else
    echo "User line found: '$line_found'"

    modified_line="    user: &wdb_user $WANDB_ENTITY"
    echo "--> Modified to: '    $modified_line'"
    
    sed -i "s|^\([[:space:]]*user: &wdb_user\).*|\1 $WANDB_ENTITY|" /home/$USER/work/nbs_pipeline/config/base.yaml
    
    
    grep "user: &wdb_user" /home/$USER/work/nbs_pipeline/config/base.yaml
fi

line_found=$(grep "^[[:space:]]*project_name: &wdb_project" /home/$USER/work/nbs_pipeline/config/base.yaml)

if [ -z "$line_found" ]; then
    echo "Project line not found."
    exit 1
else
    echo "Project line found: '$line_found'"

    modified_line="    project_name: &wdb_project $WANDB_PROJECT"
    echo "--> Modify to: '    $modified_line'"
    
    sed -i "s|^\([[:space:]]*project_name: &wdb_project\).*|\1 $WANDB_PROJECT|" /home/$USER/work/nbs_pipeline/config/base.yaml
    
    grep "project_name: &wdb_project" /home/$USER/work/nbs_pipeline/config/base.yaml
fi

[ -d "/home/$USER/data/wandb_artifacts" ] || mkdir -p "/home/$USER/data/wandb_artifacts"


if ! grep -Fxq "./path/to/check_yml_changes.sh" $HOME/work/.git/hooks/pre-commit; then \
        sed -i '$i./path/to/check_yml_changes.sh' $HOME/work/.git/hooks/pre-commit; \
    fi

exec "$@"


