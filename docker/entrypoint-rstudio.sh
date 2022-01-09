#!/bin/bash --login
set -e
echo ". ${HOME}/miniconda3/etc/profile.d/conda.sh" >> ${HOME}/.bashrc
# Make bash automatically activate the conda environment
echo "conda activate ${ENV_PREFIX}" >> ~/.bashrc
# start rstudio server
/init
exec "$@"
