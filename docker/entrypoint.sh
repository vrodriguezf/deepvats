#!/bin/bash --login
set -e
#echo $ENV_PREFIX
#conda list 
ls -la /home/$USER/work
pip install -e /home/$USER/work

echo $WANDB_ENTITY $USER $WANDB_PROJECT

### Ensuring to activate the correct conda
echo "Aqui0"
source /usr/local/share/miniconda3/etc/profile.d/conda.sh
conda activate /usr/local/share/miniconda3/envs/env

echo "Aqui2" 

#Check
conda list | grep wandb
###



echo "Aqui"

exec "$@"


