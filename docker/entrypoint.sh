#!/bin/bash --login
set -e
#echo $ENV_PREFIX
#conda list 
ls -la /home/$USER/work
pip install -e /home/$USER/work



exec "$@"
