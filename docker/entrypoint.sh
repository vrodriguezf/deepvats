#!/bin/bash --login
set -e

source /usr/local/share/miniconda3/etc/profile.d/conda.sh
conda activate /usr/local/share/miniconda3/envs/env

conda list 
ls -la /home/$USER/work

conda list pre-commit

pip install -e /home/$USER/work

exec "$@"
