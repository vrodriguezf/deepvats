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
#sudo chown -R $USER:$USER $HOME/work

sudo chown -R ${USER_NAME}:${GROUP_ID} /usr/local/share/miniconda3/envs/env/lib/python3.10/site-packages
sudo chmod -R u+rw /usr/local/share/miniconda3/envs/env/lib/python3.10/site-packages
sudo chown -R $USER:$USER $HOME
pip install -e $HOME/work

#sudo chown -R $USER:$USER $HOME/data
echo "Check conda 2"
conda list -n env moment
echo "Go!"
exec "$@"