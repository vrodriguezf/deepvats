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
    && apt-get install -y wget bzip2 curl git sudo libarchive-dev libtiff5-dev zsh python3 python3-pip\
    && apt-get clean  \
    && rm -rf /var/lib/apt/lists/*

#-- Environmental variables for wandb
ENV LC_ALL=C.UTF-8 \
    LANG=C.UTF-8 

#####################
# Install miniconda #
#####################

ENV MINICONDA_VERSION=4.10.3 \ 
    HOME=/home\
    CONDA_DIR=$HOME/miniconda3 \
    PATH=$CONDA_DIR/bin:$PATH 
ENV PROJECT_DIR=$HOME

RUN wget --quiet https://repo.anaconda.com/miniconda/Miniconda3-py38_$MINICONDA_VERSION-Linux-x86_64.sh -O $HOME/miniconda.sh  \
    && chmod +x $HOME/miniconda.sh  \
    && $HOME/miniconda.sh -b -p $CONDA_DIR  \
    && rm $HOME/miniconda.sh 

RUN echo ". $CONDA_DIR/etc/profile.d/conda.sh" >> $HOME/.profile 
RUN  conda init bash 
    #\
    # create a project directory inside user home
    #&& mkdir -p $PROJECT_DIR
#---> Esto habrá que hacerlo en jupyter/R cuando haya usuario
# no?

WORKDIR $PROJECT_DIR

##########################
# Install & update MAMBA #
########################## 
ENV ENV_PREFIX $PROJECT_DIR/env
RUN conda install --name base --channel conda-forge mamba \
    && mamba update --name base --channel defaults conda 
#-- Build the mamba environment
RUN mamba install conda-lock -c conda-forge
COPY ./docker/environment.yml ./docker/requirements.txt /tmp/
#RUN mamba lock -f /tmp/environment.yml --lockfile /tmp/environment.lock
#RUN mamba create --prefix ${ENV_PREFIX} --file /tmp/environment.lock
RUN mamba env create --prefix ${ENV_PREFIX} --file /tmp/environment.yml
RUN conda clean --all --yes



#-- Bring & Install deepvats

#RUN curl https://bootstrap.pypa.io/get-pip.py -o get-pip.py
#-- #-- No Python? WTF?
#RUN apt-get update && apt-get install -y python3 python3-pip
## This is a better way to isntall pip. As the one in apt is way outdated
#RUN python3 get-pip.py 
COPY ./ ${HOME}/work
RUN conda activate $ENV_PREFIX
RUN pip install -e $HOME/work

###### -> Cuando se cree un usuario en el otro docker
###### habrá que hacer chown y mover al nuevo home todo
###### o ver cómo hacerlo