#!/bin/bash --login
set -e

echo "--> Bashrc"
echo ". ${HOME}/miniconda3/etc/profile.d/conda.sh" >> ${HOME}/.bashrc
# Make bash automatically activate the conda environment

echo "--> Conda activate"
echo "conda activate ${ENV_PREFIX}" >> ~/.bashrc
#echo "export WANDB_ENTITY=${WANDB_ENTITY:-default}" >> ${HOME}/.bashrc
# echo "WANDB_ENTITY=${WANDB_ENTITY:-default}" >> ${HOME}/.Renviron

echo "--> Variables"
# Define an array of environment variable names from the ENV_VARS Compose variable
IFS=',' read -ra ENV_VAR_NAMES <<< "$ENV_VARS"

echo "ENV_VAR_NAMES=${ENV_VAR_NAMES[@]}"

# Loop through the array of environment variable names and set the variables
for ENV_VAR_NAME in "${ENV_VAR_NAMES[@]}"; do
  ENV_VAR_VALUE="${!ENV_VAR_NAME:-default}"
  echo "$ENV_VAR_NAME=$ENV_VAR_VALUE" >> ${HOME}/.Renviron
done

echo "--> Ulimit"
ulimit -s 16384

echo "--> Go!"
# start rstudio server
/init
exec "$@"