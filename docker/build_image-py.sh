# Inicializa un array vacío
args=()

# Lee el archivo .env línea por línea
while IFS='=' read -r key value; do
    if [[ $key != \#* && $key != '' ]]; then  # Excluye comentarios y líneas vacías
        args+=(--build-arg "$key=$value")  # Agrega --build-arg y la variable como un elemento
    fi
done < .env

# Ejecuta docker build con los argumentos
PROJECT_NAME='dvats'
IMAGE_GOALS='conda-miniconda3'
USER_NAME=$(id -un)
IMAGE_NAME=${PROJECT_NAME}'-'${IMAGE_GOALS}':latest'
# Si la imagen depende de usuario para rutas
# Usar :USER_NAME detrás de IMAGE_GOALS,
# Antes de :latest



docker build "${args[@]}" . -f Dockerfile.base -t ${IMAGE_NAME}