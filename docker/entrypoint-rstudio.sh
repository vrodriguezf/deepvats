#!/bin/bash --login
set -e

echo ". ${HOME}/miniconda3/etc/profile.d/conda.sh" >> ${HOME}/.bashrc
# Make bash automatically activate the conda environment
echo "conda activate ${ENV_PREFIX}" >> ~/.bashrc
#echo "export WANDB_ENTITY=${WANDB_ENTITY:-default}" >> ${HOME}/.bashrc
# echo "WANDB_ENTITY=${WANDB_ENTITY:-default}" >> ${HOME}/.Renviron

#... added for fixing fails when rebuilding docker ...#
### Ensuring to activate the correct conda
source /usr/local/share/miniconda3/etc/profile.d/conda.sh
conda activate /usr/local/share/miniconda3/envs/env

# Define an array of environment variable names from the ENV_VARS Compose variable
IFS=',' read -ra ENV_VAR_NAMES <<< "$ENV_VARS"

echo "ENV_VAR_NAMES=${ENV_VAR_NAMES[@]}"

# Loop through the array of environment variable names and set the variables
for ENV_VAR_NAME in "${ENV_VAR_NAMES[@]}"; do
  ENV_VAR_VALUE="${!ENV_VAR_NAME:-default}"
  echo "$ENV_VAR_NAME=$ENV_VAR_VALUE" >> ${HOME}/.Renviron
done

ulimit -s 16384

# start rstudio server
/init
exec "$@"