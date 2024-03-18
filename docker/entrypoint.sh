#!/bin/bash --login
set -e
source /usr/local/share/miniconda3/bin/activate env
#echo $ENV_PREFIX
#conda list 
ls -la /home/$USER/work
pip install -e /home/$USER/work

exec "$@"
