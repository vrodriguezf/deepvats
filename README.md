# Timecluster extension
> Extending the paper ["Timecluster: dimension reduction applied to temporal data for visual analytics"](https://link.springer.com/article/10.1007/s00371-019-01673-y) 


The intention of this repo is twofold:
1. Replicate the ideas of the Timecluster paper, and apply them to the data from PACMEL.
2. Extend the ideas of the paper for high-dimensional time series. The idea is to find the most important variables that make that a time window from
the original space (high-dimensional time series) is mapped to a specific point of the final 2D space, and focus only on them, to make it easier for the
domain expert to analyse and cluster the behaviour of the process.

## Run notebooks

To run the notebooks, install `docker` and `docker-compose` in your system. 
Then, create a new *.env* file in the root of the project following the structure:
```
# The name of the docker-compose project
COMPOSE_PROJECT_NAME=your_project_name
# The user ID you are using to run docker-compose
USER_ID=your_numeric_id
# The user name assigned to the user id
USER_NAME=your_user_name
# The port from which you want to access Jupyter lab
JUPYTER_PORT=XXXX
# The port from which you want to access RStudio server
RSTUDIO_PORT=XXXX
# The port from which you want to access Shiny
SHINY_PORT=XXXX
# The path to your data files to train/test the models
DATA_PATH = /path/to/your/data
```

Then run:

```docker-compose up -d```

and go to `localhost:7878`. The default port `7878` can be changed editing the file `docker-compose.yml`. There are several parameters (e.g., volume paths) that have to be adapted to your needs in the docker-compose file, marked as `#*`.

## Contribute

This project has been created using [nbdev](https://github.com/fastai/nbdev), a library that allows to create Python projects directly from Jupyter Notebooks. Please refer to this library when adding new functionalities to the project, in order to keep the structure of it.
