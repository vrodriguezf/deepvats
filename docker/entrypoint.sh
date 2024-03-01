#!/bin/bash --login
set -e
#echo $ENV_PREFIX
#conda list 
ls -la /home/$USER/work
pip install -e /home/$USER/work

echo $WANDB_ENTITY $USER $WANDB_PROJECT

#!/bin/bash





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

exec "$@"
