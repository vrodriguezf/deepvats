#!/bin/bash --login
set -e

[ -f ${LOG_DIR} ] && echo "${LOG_DIR} is a file" || echo "${LOG_DIR} is a directory"
[ -f ${LOG_FILE} ] && echo "${LOG_FILE} is a file" || echo "${LOG_FILE} is a directory"

echo ". ${HOME}/miniconda3/etc/profile.d/conda.sh" >> ${HOME}/.bashrc
# Make bash automatically activate the conda environment
echo "conda activate ${ENV_PREFIX}" >> ${HOME}/.bashrc

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
echo $LOG_FILE
#sudo chown app:app "$LOG_FILE"
sudo chown -R $UID:shared "$LOG_DIR"
sudo chmod -R 775 /var/log/shiny-server

ls -la $LOG_DIR

echo "DEBUG: Writing to ${LOG_FILE}" >> ${LOG_FILE}
exec >> $LOG_FILE 2>&1

R --quiet -e "shiny::runApp('${APP}', host='0.0.0.0', port=3838)"