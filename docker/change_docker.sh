#!/bin/bash

if [ -f "docker-compose.yml" ]; then
    mv "docker-compose.yml" "docker_compose.yml__"
fi

if [ -f "docker_compose.yml_" ]; then
    mv "docker_compose.yml_" "docker_compose.yml"
fi

if [ -f "docker_compose.yml__" ]; then
    mv "docker_compose.yml__" "docker_compose.yml_"
fi

if [ -f "Dockerfile.jupyter" ]; then
    mv "Dockerfile.jupyter" "Dockerfile_jupyter__"
fi

if [ -f "Dockerfile_jupyter_" ]; then
    mv "Dockerfile_jupyter_" "Dockerfile.jupyter"
fi

if [ -f "Dockerfile_jupyter__" ]; then
    mv "Dockerfile_jupyter__" "Dockerfile_jupyter_"
fi

if [ -f "Dockerfile.rstudio" ]; then
    mv "Dockerfile.rstudio" "Dockerfile_rstudio__"
fi

if [ -f "Dockerfile_rstudio_" ]; then
    mv "Dockerfile_rstudio_" "Dockerfile.rstudio"
fi

if [ -f "Dockerfile_rstudio__" ]; then
    mv "Dockerfile_rstudio__" "Dockerfile_rstudio_"
fi

