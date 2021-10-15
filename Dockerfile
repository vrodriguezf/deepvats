FROM vrodriguezf/jupyterlab-cuda:latest

# Add non-root user (call this with the specific UID and GID of the host, to share permissions)
ARG USER_ID=1000
ARG GROUP_ID=1000
ARG USER=user
RUN addgroup --gid $GROUP_ID $USER
RUN adduser --disabled-password --gecos '' --uid $USER_ID --gid $GROUP_ID $USER

###
# Python packages
###
RUN pip install --upgrade nbdev wandb fastcore papermill umap-learn tensorflow keras seaborn plotly
RUN pip install hdbscan --no-cache-dir --no-binary :all:
RUN pip install tsnecuda==3.0.0+cu112 -f https://tsnecuda.isx.ai/tsnecuda_stable.html

# Git packages
ENV LANG C.UTF-8

# Editable packages
RUN mkdir /home/$USER/lib
RUN cd /home/$USER/lib \
    && git clone https://github.com/timeseriesAI/tsai.git \
    && cd tsai \ 
    && pip install -e .


# Copy the default jupyterlab settings user settings to the new user folder
RUN cp -r /.jupyter /home/$USER/.jupyter
RUN chown -R $USER_ID:$GROUP_ID /home/$USER/.jupyter


# Change the ownership of the editable installs within the lib folder
RUN chown -R $USER:$USER /home/$USER/lib

# Environmental variables for wandb
ENV LC_ALL=C.UTF-8
ENV LANG=C.UTF-8


# Create non root user home folder
USER $USER
WORKDIR /home/$USER
