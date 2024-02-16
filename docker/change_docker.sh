#!/bin/bash

if [ -f "docker-compose.yml" ]; then
    mv "docker-compose.yml" "docker-compose.yml__"
else
	exit
fi

if [ -f "docker-compose.yml_" ]; then
    mv "docker-compose.yml_" "docker-compose.yml"
else 
	mv "docker-compose.yml__" "docker-compose.yml"
	exit
fi

if [ -f "docker-compose.yml__" ]; then
    mv "docker-compose.yml_" "docker-compose.yml_"
else 
	exit
fi

if [ -f "Dockerfile.jupyter" ]; then
    mv "Dockerfile.jupyter" "Dockerfile.jupyter__"
else
    mv "docker-compose.yml" "docker-compose.yml__"
    mv "docker-compose.yml_" "docker-compose.yml"
    mv "docker-compose.yml__" "docker-compose.yml_"
    exit
fi

if [ -f "Dockerfile.jupyter_" ]; then
    mv "Dockerfile-jupyter_" "Dockerfile.jupyter"
    exit
fi

if [ -f "Dockerfile.jupyter__" ]; then
    mv "Dockerfile.jupyter__" "Dockerfile.jupyter_"
    exit
fi

if [ -f "Dockerfile.rstudio" ]; then
    mv "Dockerfile.rstudio" "Dockerfile.rstudio__"
    exit
fi

if [ -f "Dockerfile.rstudio_" ]; then
    mv "Dockerfile.rstudio_" "Dockerfile.rstudio"
    exit
fi

if [ -f "Dockerfile.rstudio__" ]; then
    mv "Dockerfile.rstudio__" "Dockerfile.rstudio_"
    exit
fi

