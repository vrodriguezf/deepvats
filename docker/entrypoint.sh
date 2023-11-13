#!/bin/bash --login
set -e
echo $ENV_PREFIX
conda activate $ENV_PREFIX
conda list 
pip install -e /home/$USER/work
exec "$@"
