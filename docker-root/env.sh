#!/bin/bash

USER_ID=$(id -u)
GROUP_ID=$(id -g)
USER_NAME=$(id -un)

# Crear o sobrescribir el archivo .env con la información recopilada
cat > .env << EOF
# The name of the docker-compose project
COMPOSE_PROJECT_NAME=dvats-${USER_NAME}
# The user ID you are using to run docker-compose
USER_ID=${USER_ID}
# The group ID you are using to run docker-compose (you can get it with id -g in a terminal)
GROUP_ID=${GROUP_ID}
# The user name assigned to the user id
USER_NAME=${USER_NAME}
# The port from which you want to access Jupyter lab (modify)
JUPYTER_PORT=<your preferred port>
# The token used to access (like a password) (modify)
JUPYTER_TOKEN=<your_password>
# The path toz your data files to train/test the models (modify if needed)
LOCAL_DATA_PATH=/home/${USER_NAME}/work_dir
# The W&B entity (modify)
WANDB_ENTITY=<your_wandb_username>
# The W&B project (modify if needed)
WANDB_PROJECT=deepvats
# The W&B personal API key (see https://wandb.ai/authorize)
WANDB_API_KEY=<your wandb API key. Instructions in the link above>
# List of comma separated GPU indices that will be available in the container (by default only 0, the first one) (modify. Check your devices id via nvidia-smi)
CUDA_VISIBLE_DEVICES=0,1
# Github PAT (see https://docs.github.com/en/github/authenticating-to-github/keeping-your-account-and>
GH_TOKEN=<your_gh_token> Check the instructions in the link above.
# Port in which you want Rstudio server to be deployed (for developing in the front end)
RSTUDIO_PORT=<your preferred port>
# Password to access the Rstudio server
RSTUDIO_PASSWD=<password>

EOF

echo ".env successfuly generated"


