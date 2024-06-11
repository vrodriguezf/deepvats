#!/bin/bash
# Inicializa un array vacío
args=()

# Lee el archivo .env línea por línea
IFS='='
while IFS='=' read -r key value _; do
    value="${value%$'\r'}"
    #echo "key: $key"
    #echo "value: $value"
    if [[ $key != \#* && $key != '' ]]; then  # Excluye comentarios y líneas vacías
        args+=(--build-arg "$key=$value")  # Agrega --build-arg y la variable como un elemento
    else
        echo "Skipping $key = $value"
    fi
done < docker/.env

#echo "Args:" "${args[@]}"


# Ejecuta docker build con los argumentos
PROJECT_NAME='dvats'
echo "Get docker"
DOCKER=$1
VERSION=$2
#IMAGE_GOALS='conda-miniconda3'
USER_NAME=$(id -un)
echo "DOCKER: $DOCKER"
if [ "$DOCKER" = 'jupyter' ]; then
    DOCKERFILE=./docker/Dockerfile.jupyter.base
    else 
    DOCKERFILE=./docker/Dockerfile.rstudio.base
fi

echo "Dockerfile: $DOCKERFILE"
IMAGE_NAME=${PROJECT_NAME}-$DOCKER':'$VERSION

#read -p "Docker $DOCKER Dockerfile: $DOCKERFILE Image: $IMAGE_NAME"
# Si la imagen depende de usuario para rutas
# Usar :USER_NAME detrás de IMAGE_GOALS,
# Antes de :latest


echo "IMAGE_NAME: $IMAGE_NAME"
docker build "${args[@]}" . -f ${DOCKERFILE} -t ${IMAGE_NAME}
