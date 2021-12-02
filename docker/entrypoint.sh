#!/bin/bash --login
set -e
conda activate $ENV_PREFIX
pip install -e /home/$USER/work
exec "$@"
