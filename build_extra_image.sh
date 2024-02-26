DOCKER=$1
VERSION=$2
IMAGE_GOALS=$3 #hooks
PROJECT_NAME=$(grep -oP '^COMPOSE_PROJECT_NAME=\K.*' ./docker/.env)
USER_NAME=$(id -un)

echo "DOCKER: $DOCKER | PROJECT_NAME: $PROJECT_NAME | USER_NAME: $USER_NAME | VERSION: $VERSION | IMAGE_GOALS: $IMAGE_GOALS"

if [ "$DOCKER" = 'jupyter' ]; then
    DOCKERFILE=./docker/Dockerfile.jupyter.${IMAGE_GOALS}
    else 
    DOCKERFILE=./docker/Dockerfile.rstudio.${IMAGE_GOALS}
fi

echo "Dockerfile: $DOCKERFILE"
IMAGE_NAME=${PROJECT_NAME}-$DOCKER':'$VERSION-$IMAGE_GOALS

echo "IMAGE_NAME: $IMAGE_NAME"
docker build  . -f "${DOCKERFILE}" -t "${IMAGE_NAME}"
