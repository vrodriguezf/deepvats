# Timecluster extension
> Extending the paper ["Timecluster: dimension reduction applied to temporal data for visual analytics"](https://link.springer.com/article/10.1007/s00371-019-01673-y) 


The intention of this repo is twofold:
1. Replicate the ideas of the Timecluster paper, and apply them to the data from PACMEL.
2. Extend the ideas of the paper for high-dimensional time series. The idea is to find the most important variables that make that a time window from
the original space (high-dimensional time series) is mapped to a specific point of the final 2D space, and focus only on them, to make it easier for the
domain expert to analyse and cluster the behaviour of the process.

## Run notebooks

To run the notebooks, install `docker` and `docker-compose` in your system. Then run:

```docker-compose up -d```

and go to `localhost:7878`. The default port `7878` can be changed editing the file `docker-compose.yml`

## Contribute

This project has been created using [nbdev](https://github.com/fastai/nbdev), a library that allows to create Python projects directly from Jupyter Notebooks. Please refer to this library when adding new functionalities to the project, in order to keep the structure of it.
