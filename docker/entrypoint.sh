#!/bin/bash --login
set -e
#echo $ENV_PREFIX
#conda list 
#conda install -cy conda-forge pre-commit
ls -la /home/$USER/work
pip install -e /home/$USER/work
exec "$@"
