#!/bin/bash --login
set -e
conda activate $ENV_PREFIX
pip install -e /home/$USER/work
pip install protobuf==3.18.1
exec "$@"
