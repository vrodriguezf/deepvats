#!/bin/bash --login
set -e

### Ensuring to activate the correct conda
echo "activating conda"
source /usr/local/share/miniconda3/etc/profile.d/conda.sh
conda activate /usr/local/share/miniconda3/envs/env
#Check
echo "check conda 1"
conda list -n env moment

############################
# Extra pre-commit options #
############################
echo "Ensure permissions"
sudo chown -R $USER:$USER $HOME/work
sudo chown -R $USER:$USER $HOME/data
echo "Check conda 2"
conda list -n env moment
echo "Go!"
exec "$@"