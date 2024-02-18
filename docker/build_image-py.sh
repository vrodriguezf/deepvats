# Inicializa un array vacío
args=()

# Lee el archivo .env línea por línea
IFS='='
while IFS='=' read -r key value _; do
    value="${value%$'\r'}"
    echo "key: $key"
    echo "value: $value"
    if [[ $key != \#* && $key != '' ]]; then  # Excluye comentarios y líneas vacías
        args+=(--build-arg "$key=$value")  # Agrega --build-arg y la variable como un elemento
    else
        echo "Skipping $key = $value"
    fi
done < .env

echo "Args:" "${args[@]}"
#read -p "Press enter to continue"

# Ejecuta docker build con los argumentos
PROJECT_NAME='dvats'
IMAGE_GOALS='conda-miniconda3'
USER_NAME=$(id -un)
IMAGE_NAME=${PROJECT_NAME}'-'${IMAGE_GOALS}':latest'
# Si la imagen depende de usuario para rutas
# Usar :USER_NAME detrás de IMAGE_GOALS,
# Antes de :latest

DOCKERFILE=Dockerfile.py

docker build "${args[@]}" . -f ${DOCKERFILE} -t ${IMAGE_NAME}