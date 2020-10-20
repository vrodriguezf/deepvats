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
LOCAL_DATA_PATH=/path/to/your/data
```

Then run:

```docker-compose up -d```

and go to `localhost:7878`. The default port `7878` can be changed editing the file `docker-compose.yml`. There are several parameters (e.g., volume paths) that have to be adapted to your needs in the docker-compose file, marked as `#*`.

## Standard working procedure for resolving gitlab issues
We recommend using the following procedure to resolve issues in the repository:
1. Create a local branch in your development environment to solve the issue XX:
    ```
    git checkout -b issueXX
    ```

2. Add/make changes to the code to resolve the issue
3. Make a commit of the changes made
    ``` 
    git commit -m "Fix issue #XX"
    ```
4. Test that there are not merging problems in the Jupyter Notebooks with the function [**nbdev_fix_merge**](https://nbdev.fast.ai/cli#nbdev_fix_merge)

5.  Push your local branch to a branch in the gitlab repository with an identiffying name:
    ```
    git push -u origin issueXX_solved
    ```
6. When the push is made, a link will appear in the terminal to create a merge request. Click on it.
    ```
    remote:
    remote: To create a merge request for test_branch, visit:
    remote:   https://gitlab.geist.re/pml/x_timecluster_extension/-/merge_requests/new?merge_request%5Bsource_branch%5D=issueXX_solved
    remote:
    ```
7. In the gitlab website:
    * Write in the description what is the problem to solve with your branch using a hyperlink to the issue (just use the hashtag symbol "#" followed by the issue number) 
    * Click on the option "Delete source branch when merge request is accepted" and assign the merge to your profile.
    * Click on the button "Create merge request"
![image](/uploads/da18a985a69973ad62a60bc6564304b9/image.png)

8. Wait to the merge to be accepted. We recommend to move the issue to the field "In review" (in the Issue Board).
9. If there are no problems, the merge request will be accepted and the issue will be closed.


## Contribute

This project has been created using [nbdev](https://github.com/fastai/nbdev), a library that allows to create Python projects directly from Jupyter Notebooks. Please refer to this library when adding new functionalities to the project, in order to keep the structure of it.
