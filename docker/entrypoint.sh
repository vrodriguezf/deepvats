#!/bin/bash --login
echo "About to exec deepvats\docker\entrypoint.sh"
set -e
conda activate $ENV_PREFIX
pip install -e /home/$USER/work
exec "$@"
