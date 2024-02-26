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

COMMAND="cd work && git add --all && git commit -m \"$COMMIT_MESSAGE\" && git push"
SERVICE_RUNNING=$(docker-compose -f ${COMPOSE_FILE} ps | grep $SERVICE_NAME | grep "Up")

if [ -z "$SERVICE_RUNNING" ]; then
  echo "Service $SERVICE_NAME not running. Commiting inside"
  
  echo "Starting service $SERVICE_NAME..."
  docker-compose -f $COMPOSE_FILE up -d $SERVICE_NAME
  # Wait for the service to start
  sleep 5
  
  echo "Executing command inside $SERVICE_NAME..."
  echo "docker-compose -f $COMPOSE_FILE exec -T $SERVICE_NAME sh -c $COMMAND"
  docker-compose -f $COMPOSE_FILE exec -T $SERVICE_NAME sh -c "$COMMAND"

  # Verificar el estado de salida del comando anterior
  if [ $? -ne 0 ]; then
    echo "Error: Commit failed"
  else 
    echo "Commit done"
  fi  

  echo "Stopping service $SERVICE_NAME..."
  docker-compose -f $COMPOSE_FILE stop $SERVICE_NAME
  else 
  echo "Service $SERVICE_NAME running. Please use git from inside the docker or stop it"
  read -p "PLEASE! TAKE CARE! IF YOU CONTINUE COMMITING OUTPUTS WILL BE ADDED TO GIT. PRESS ENTER TO CONTINUE."
  echo "Commit will not be done in this script. Decide if doing it from outside or inside. Ensure the correct git add..."
fi

exit 0

