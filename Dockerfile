FROM vrodriguezf/jupyterlab-cuda:latest

# PYTHON PACKAGES with pip
RUN pip install nbdev
RUN pip install umap-learn
RUN pip install fastcore
RUN pip install tensorflow
RUN pip install keras
RUN pip install papermill
RUN pip install wandb==0.9.1 # Newer versions have bugs with the use of artifacts
RUN pip install seaborn
RUN pip install plotly

# Environmental variables for wandb
RUN export LC_ALL=C.UTF-8
RUN export LANG=C.UTF-8

# Add non-root user (call this with the specific UID and GIO of the host, to share permissions)
ARG USER_ID=1000
ARG GROUP_ID=1000
ARG USER=user

RUN addgroup --gid $GROUP_ID $USER
RUN adduser --disabled-password --gecos '' --uid $USER_ID --gid $GROUP_ID $USER
USER $USER
WORKDIR /home/$USER


