#!/bin/bash --login
set -e
pip install -e /home/victor/work
conda activate $ENV_PREFIX
exec "$@"
