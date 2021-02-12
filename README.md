# Timecluster extension
> Extending the paper <a href='https://link.springer.com/article/10.1007/s00371-019-01673-y'>"Timecluster: dimension reduction applied to temporal data for visual analytics"</a> 


The intention of this repo is twofold:
1. Replicate the ideas of the Timecluster paper, and apply them to the data from PACMEL.
2. Extend the ideas of the paper for high-dimensional time series. The idea is to find the most important variables that make that a time window from
the original space (high-dimensional time series) is mapped to a specific point of the final 2D space, and focus only on them, to make it easier for the
domain expert to analyse and cluster the behaviour of the process.

The process consists in the following steps:

1. Normalize the data
2. Extract features from the time series. We will use a rolling window strategy
3. 2D projection of the data through UMAP
4. Link points in the 2d projection to the corresponding sliding window, highlighting not only the time window but also the morst important variables that contributed in the point being in that place of the projection.

## Run notebooks

To run the notebooks, install `docker` and `docker-compose` in your system. Then run:

```docker-compose up -d```

and go to `localhost:[PORT_NUMBER]`, where port number is specified in the file `docker-compose.yml`

## How to use

```
# list the runs of my profile
```

## Contribute

This project has been created using [nbdev](https://github.com/fastai/nbdev), a library that allows to create Python projects directly from Jupyter Notebooks. Please refer to this library when adding new functionalities to the project, in order to keep the structure of it.

The experiment tracking and hyperparameter tuning has been carried out using the library [Weights & Biases](https://app.wandb.ai/). Please login to this system if you want to run these experiments.
