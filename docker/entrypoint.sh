#!/bin/bash --login
echo "About to exec deepvats\docker\entrypoint.sh"

set -e
#conda list --prefix $ENV_PREFIX
conda activate $ENV_PREFIX

#echo $ENV_PREFIX
#echo $PATH
#conda list 
pip install -e /home/$USER/work
exec "$@"
