FROM vrodriguezf/jupyterlab-cuda

# PYTHON PACKAGES
RUN pip install nbdev
RUN pip install umap-learn
RUN pip install fastcore
RUN pip install keras
RUN pip install tensorflow
RUN pip install papermill
RUN pip install wandb --upgrade
RUN pip install seaborn

