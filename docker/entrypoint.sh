#!/bin/bash --login
set -e
#echo $ENV_PREFIX
#conda list 
ls -la /home/$USER/work
pip install -e /home/$USER/work

echo $WANDB_ENTITY $USER $WANDB_PROJECT

#!/bin/bash

line_found=$(grep "^[[:space:]]*user: &wdb_user$" /home/$USER/work/nbs_pipeline/config/base.yaml)

if [ -z "$line_found" ]; then
    echo "Línea no encontrada."
else
    echo "Línea encontrada: '$line_found'"

    modified_line="    user: &wdb_user $WANDB_ENTITY"
    echo "--> Modificando a: '    $modified_line'"
    
    sed -i "s|^\([[:space:]]*user: &wdb_user\).*|\1 $WANDB_ENTITY|" /home/$USER/work/nbs_pipeline/config/base.yaml
    
    grep "user: &wdb_user" /home/$USER/work/nbs_pipeline/config/base.yaml
fi

exec "$@"
