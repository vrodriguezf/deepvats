############################################
# CONDA & MINICONDA WITH PYBASE DOCKERFILE #
############################################
##############
# Base image #
##############
##--- Setup Ubuntu
ARG CUDA_VERSION=$CUDA_VERSION

FROM nvidia/cuda:${CUDA_VERSION}

##--- Tags
LABEL maintainer="vrodriguezf <victor.rfernandez@upm.es>"
LABEL cuda_version=${CUDA_VERSION}
LABEL cuda_version=${CUDA_VERSION}

##--- Setup bash
SHELL [ "/bin/bash", "--login", "-c" ]

##################
# Packages setup #
################## 
#TODO: Automatizar que lo coja de /etc/timezone
ARG TZ=Etc/UTC 
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone \
    && apt-get update --fix-missing \
    && apt-get install -y wget bzip2 curl git sudo libarchive-dev libtiff5-dev zsh\
    && apt-get clean  \
    && rm -rf /var/lib/apt/lists/*

#-- Environmental variables for wandb
ENV LC_ALL=C.UTF-8 \
    LANG=C.UTF-8 

#####################
# Install miniconda #
#####################

ENV MINICONDA_VERSION=4.10.3 \ 
#ENV MINICONDA_VERSION=23.9.0 \ 
    CONDA_DIR=$HOME/miniconda3 \
    # Make non-activate conda commands available
    PATH=$CONDA_DIR/bin:$PATH \
    HOME=~\
    PROJECT_DIR=$HOME

RUN echo "HOME: ${HOME} | CONDA_DIR = ${CONDA_DIR}" \
    #-- Install MINICONDA
    && wget --quiet https://repo.anaconda.com/miniconda/Miniconda3-py38_$MINICONDA_VERSION-Linux-x86_64.sh -O ~/miniconda.sh  \
    && chmod +x ~/miniconda.sh  \
    && ~/miniconda.sh -b -p $CONDA_DIR  \
    && rm ~/miniconda.sh 

#-- Bring & Install deepvats
COPY ./ ${HOME}/work
RUN conda activate $ENV_PREFIX
RUN pip install -e /home/$USER/work

###### -> Cuando se cree un usuario en el otro docker
###### habrá que hacer chown y mover al nuevo home todo
###### o ver cómo hacerlo