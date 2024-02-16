#!/bin/bash

if [ -f "docker-compose.yml" ]; then
    mv "docker-compose.yml" "docker-compose.yml__"
fi

if [ -f "docker-compose.yml_" ]; then
    mv "docker-compose.yml_" "docker-compose.yml"
fi

if [ -f "docker-compose.yml__" ]; then
    mv "docker-compose.yml_" "docker-compose.yml_"
fi

if [ -f "Dockerfile.jupyter" ]; then
    mv "Dockerfile.jupyter" "Dockerfile.jupyter__"
fi

if [ -f "Dockerfile.jupyter_" ]; then
    mv "Dockerfile-jupyter_" "Dockerfile.jupyter"
fi

if [ -f "Dockerfile.jupyter__" ]; then
    mv "Dockerfile.jupyter__" "Dockerfile.jupyter_"
fi

if [ -f "Dockerfile.rstudio" ]; then
    mv "Dockerfile.rstudio" "Dockerfile.rstudio__"
fi

if [ -f "Dockerfile.rstudio_" ]; then
    mv "Dockerfile.rstudio_" "Dockerfile.rstudio"
fi

if [ -f "Dockerfile.rstudio__" ]; then
    mv "Dockerfile.rstudio__" "Dockerfile.rstudio_"
fi

