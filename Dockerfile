FROM vrodriguezf/jupyterlab-cuda:latest

# Install and update Python packages with pip
RUN python3 -m pip install --upgrade pip
RUN pip install nbdev umap-learn tensorflow keras seaborn plotly
RUN pip install --upgrade wandb fastcore papermill
RUN pip install hdbscan --no-cache-dir --no-binary :all:

# Add non-root user (call this with the specific UID and GID of the host, to share permissions)
ARG USER_ID=1000
ARG GROUP_ID=1000
ARG USER=user
RUN addgroup --gid $GROUP_ID $USER
RUN adduser --disabled-password --gecos '' --uid $USER_ID --gid $GROUP_ID $USER


# Copy the default jupyterlab settings user settings to the new user folder
RUN cp -r /.jupyter /home/$USER/.jupyter
RUN chown -R $USER_ID:$GROUP_ID /home/$USER/.jupyter


# Create non root user home folder
WORKDIR /home/$USER

USER $USER
