#!/bin/bash

echo "Move docker-compose.yml --> docker-compose.yml__"
mv "docker-compose.yml" "docker-compose.yml__"

echo "Move docker-compose.yml_ --> docker-compose.yml"
mv "docker-compose.yml_" "docker-compose.yml"

echo "Move docker-compose.yml__ --> docker-compose.yml_"
mv "docker-compose.yml__" "docker-compose.yml_"

echo "Move Dockerfile.jupyter --> Dockerfile.jupyter__"
mv "Dockerfile.jupyter" "Dockerfile.jupyter__"

echo "Move Dockerfile.jupyter_ --> Dockerfile.jupyter"
mv "Dockerfile.jupyter_" "Dockerfile.jupyter"

echo "Move Dockerfile.jupyter__ --> Dockerfile.jupyter_"
mv "Dockerfile.jupyter__" "Dockerfile.jupyter_"

echo "Move Dockerfile.rstudio --> Dockerfile.rstudio__"
mv "Dockerfile.rstudio" "Dockerfile.rstudio__"

echo "Move Dockerfile.rstudio_ --> Dockerfile.rstudio"
mv "Dockerfile.rstudio_" "Dockerfile.rstudio"

echo "Move Dockerfile.rstudio__ --> Dockerfile.rstudio_"
mv "Dockerfile.rstudio__" "Dockerfile.rstudio_"
