FROM vrodriguezf/jupyterlab-cuda:latest

# PYTHON PACKAGES with pip
RUN pip install nbdev
RUN pip install umap-learn
RUN pip install tensorflow
RUN pip install keras
RUN pip install papermill
RUN pip install seaborn
RUN pip install plotly

## Python packages that need to be upgraded
RUN pip install --upgrade wandb fastcore

# Environmental variables for wandb
ENV LC_ALL=C.UTF-8
ENV LANG=C.UTF-8

# Add non-root user (call this with the specific UID and GIO of the host, to share permissions)
ARG USER_ID=1000
ARG GROUP_ID=1000
ARG USER=user

RUN addgroup --gid $GROUP_ID $USER
RUN adduser --disabled-password --gecos '' --uid $USER_ID --gid $GROUP_ID $USER
# Create non root user home folder
WORKDIR /home/$USER
# setup share data folder before switching to user
#RUN mkdir /home/$USER/data
#RUN mkdir /home/$USER/data/PACMEL-2019
#RUN chown -R $USER:$USER /home/$USER/data
USER $USER
