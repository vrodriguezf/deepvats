FROM jupyter/datascience-notebook

# NECCESARY FOR RUNNING R CODE
#RUN apt-get -qq update
#RUN apt-get install -y software-properties-common
#RUN apt-get install -y libxml2-dev
#RUN apt-get install -y r-base

# PYTHON PACKAGES
RUN pip install nbdev
RUN pip install umap-learn
RUN pip install fastcore
RUN pip install jupyter_contrib_nbextensions
RUN pip install tqdm
RUN pip install keras
RUN pip install tensorflow
RUN pip install voila
RUN pip install bqplot
RUN pip install ipyvuetify
RUN pip install ipympl
RUN pip install voila-vuetify
RUN pip install papermill
RUN pip install --upgrade https://github.com/wandb/client/archive/pilot/artifacts.zip
RUN pip install plotly

# R PACKAGES
RUN Rscript -e "install.packages(c('xts'), repo = 'http://cran.rstudio.com/')"

# user id for jupyter
ARG user_id=1000

USER root

# CHANGE THE USER AND GROUP OF JOVYAN
RUN usermod -u $user_id jovyan
#RUN groupmod -g $user_id jovyan

USER jovyan

WORKDIR /home/jovyan

# MAKE DEFAULT CONFIG
# RUN jupyter notebook --generate-config
RUN mkdir data

# Install Jupyter extensions
RUN jupyter contrib nbextension install --user
RUN jupyter nbextensions_configurator enable --user
RUN jupyter nbextension enable collapsible_headings/main --user

#####
# jupyterlab extensions
####
RUN pip install --upgrade jupyterlab-git
RUN pip install --upgrade jupyterlab-quickopen
RUN jupyter lab build
RUN jupyter labextension install @jupyter-voila/jupyterlab-preview
RUN jupyter labextension install @parente/jupyterlab-quickopen
RUN jupyter labextension install @ijmbarr/jupyterlab_spellchecker
RUN jupyter labextension install @krassowski/jupyterlab_go_to_definition@0.7.1
# Code formatter
RUN jupyter labextension install @ryantam626/jupyterlab_code_formatter
RUN pip install jupyterlab_code_formatter
RUN jupyter serverextension enable --py jupyterlab_code_formatter
RUN pip install black



