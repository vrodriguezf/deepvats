#!/bin/bash --login
set -e
# make conda activate command available from /bin/bash --login shells
echo ". $RETICULATE_MINICONDA_PATH/etc/profile.d/conda.sh" >> $HOME/.profile
/init
#conda activate $ENV_PREFIX
exec "$@"
