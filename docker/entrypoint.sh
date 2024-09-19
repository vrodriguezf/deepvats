#!/bin/bash --login
set -e
#echo $ENV_PREFIX
#conda list 
ls -la /home/$USER/work
pip install -e /home/$USER/work

echo $WANDB_ENTITY $USER $WANDB_PROJECT

### Ensuring to activate the correct conda
source /usr/local/share/miniconda3/etc/profile.d/conda.sh
conda activate /usr/local/share/miniconda3/envs/env
#pip install git+https://github.com/moment-timeseries-foundation-model/moment.git
#pip install "tsfm_public[notebooks] @ git+https://github.com/ibm-granite/granite-tsfm.git" --no-deps
#conda install -c huggingface -c conda-forge datasets multidict aiohttp multiprocess xxhash -y


#echo "--------------------------------------------- installing dill ---------------------------------------------"
#conda install conda-forge::dill
#Check
conda list | grep moment
###

#!/bin/bash

############################
# Extra pre-commit options #
############################

#Check
conda list | grep wandb
###



echo "Aqui"

exec "$@"


