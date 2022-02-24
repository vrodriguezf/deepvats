#!/bin/bash --login
set -e
echo ". ${RETICULATE_CONDA}/etc/profile.d/conda.sh" >> ${HOME}/.bashrc
# Make bash automatically activate the conda environment
echo "conda activate ${RETICULATE_CONDA}" >> ~/.bashrc
# start rstudio server
/init
exec "$@"
