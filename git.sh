#!/bin/bash

SERVICE_NAME="jupyter"

if [ "$#" -eq 0 ]; then
  read -p "Please provide a commit message in the next window. Press enter to continue."
  COMMIT_FILE=$(mktemp)
  trap "rm -f $COMMIT_FILE" EXIT
  vim "$COMMIT_FILE"
  COMMIT_MESSAGE=$(cat "$COMMIT_FILE")
else 
  COMMIT_MESSAGE="$1"
fi


COMPOSE_FILE="./docker/docker-compose.yml"
GH_TOKEN=$(grep -oP '^GH_TOKEN=\K.*' ./docker/.env)

USER_EMAIL=$(git config user.email)
USER_NAME=$(git config user.name)


COMMAND="cd work && "
COMMAND=${COMMAND}"git config --global credential.helper store && echo "https://github.com:${GH_TOKEN}@github.com" > ~/.git-credentials"
COMMAND=${COMMAND}" && git config --global user.email \"$USER_EMAIL\" && git config --global user.name \"$USER_NAME\""
COMMAND=${COMMAND}" && git add --all && git commit -m \"$COMMIT_MESSAGE\" && git push"

SERVICE_RUNNING=$(docker-compose -f ${COMPOSE_FILE} ps | grep $SERVICE_NAME | grep "Up")
SERVICE_RUNNING_=FALSE

if [ -z "$SERVICE_RUNNING" ]; then
  SERVICE_RUNNING_=TRUE
  echo "Service $SERVICE_NAME not running. Commiting inside"
  
  echo "Starting service $SERVICE_NAME..."
  docker-compose -f $COMPOSE_FILE up -d $SERVICE_NAME
  # Wait for the service to start
  sleep 5
  
  echo "Executing command inside $SERVICE_NAME..."
  
else
  echo "Service $SERVICE_NAME already running."
  
fi
echo "About to exec: docker-compose -f $COMPOSE_FILE exec -T $SERVICE_NAME sh -c $COMMAND"
docker-compose -f $COMPOSE_FILE exec -T $SERVICE_NAME sh -c "$COMMAND"
# Verificar el estado de salida del comando anterior
  if [ $? -ne 0 ]; then
    echo "Error: Commit failed"
  else 
    echo "Commit done"
  fi  

if [ -z "$SERVICE_RUNNING_" ]; then 
  echo "Stopping service $SERVICE_NAME..."
  docker-compose -f $COMPOSE_FILE stop $SERVICE_NAME
  echo "Service $SERVICE_NAME stopped"
fi 

exit 0

