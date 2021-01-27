# Timecluster hub
> Hub for different visual analytics approaches for high-dimensional time series. Inspired by the paper ["Timecluster: dimension reduction applied to temporal data for visual analytics"](https://link.springer.com/article/10.1007/s00371-019-01673-y) 


The main intention of this repo is twofold:
1. Replicate the ideas of the Timecluster paper, and apply them to the data from PACMEL.
2. Extend the ideas of the paper for high-dimensional time series. The idea is to find the most important variables that make that a time window from
the original space (high-dimensional time series) is mapped to a specific point of the final 2D space, and focus only on them, to make it easier for the
domain expert to analyse and cluster the behaviour of the process.

The visual part of this repo can also be used as a testbed to validate different approaches to unsupervised learning for time series data. This includes clustering, anomaly detection, segmentation, annotation...

## Deploy

To run the notebooks and the app, install `docker` and `docker-compose` in your system. 
Then, create a new *.env* file in the root of the project following the structure:
```
# The name of the docker-compose project
COMPOSE_PROJECT_NAME=your_project_name
# The user ID you are using to run docker-compose
USER_ID=your_numeric_id
# The group ID you are using to run docker-compose (you can get it with id -g in a terminal)
GROUP_ID=your_numeric_id
# The user name assigned to the user id
USER_NAME=your_user_name
# The port from which you want to access Jupyter lab
JUPYTER_PORT=XXXX
# The port from which you want to access RStudio server
RSTUDIO_PORT=XXXX
# The password you want to access RStudio server (user is given by USER_NAME)
RSTUDIO_PASSWD=XXXX
# The path to your data files to train/test the models
LOCAL_DATA_PATH=/path/to/your/data
# The W&B personal API key (see https://wandb.ai/authorize)
WANDB_API_KEY=your_wandb_api_key
```

You'll also need to have a `.gitconfig` file in your home folder. It can be an empty file that you create manually, or it can contain your git global configuration. For the latter case, run:
- `git config --global user.name "YOUR NAME IN THIS GITLAB INSTANCE"`
- `git config --global user.email "YOUR EMAIL IN THIS GITLAB INSTANCE"`

This will automatically create the `~/.gitconfig` file in your home folder.

Finally, in a terminal located in the root of this repository, run:

```docker-compose up -d --build```

then go to `localhost:{{JUPYTER_PORT}}` to run the notebooks or go to `localhost:{{RSTUDIO_PORT}}` to run the app. In case you are working in a remote server, replace `localhost` with the IP of your remote server.


## Contribute
This project has been created using [nbdev](https://github.com/fastai/nbdev), a library that allows to create Python projects directly from Jupyter Notebooks. Please refer to this library when adding new functionalities to the project, in order to keep the structure of it.

We recommend using the following procedure to contribute and resolve issues in the repository:

1. Because the project uses nbdev, we need to run `nbdev_install_git_hooks` the first time after the repo is cloned and deployed; this ensures that our notebooks are automatically cleaned and trusted whenever we push to Github/Gitlab. The command has to be run from within the container. 

1. Create a local branch in your development environment to solve the issue XX (or add a new functionality), with the name you want to give your merge request (use something that will be easy for you to remember in the future if you need to update your request):
    ```
    git checkout -b issueXX
    ```

2. Make whatever changes you want to make in the code and notebooks, and remember to run nbdev_build_lib when you're done to ensure that the libraries are built from your notebook changes (unless you only changed markdown, in which case that's not needed). It's also a good idea to check the output of git diff to ensure that you haven't accidentally made more changes than you planned.

3. Make a commit of the changes made
    ``` 
    git commit -am "Fix issue #XX"
    ```

4. Test that there are not merging problems in the Jupyter Notebooks with the function [**nbdev_fix_merge**](https://nbdev.fast.ai/cli#nbdev_fix_merge)

5.  Push your local branch to a branch in the gitlab repository with an identiffying name:
    ```
    git push -u origin HEAD
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

8. Wait to the merge to be accepted. In case you're solving an issue, we recommend to move the issue to the field "In review" (in the Issue Board). To keep your branch up to date with the changes to the main repo, run:
```
git pull upstream master
```

9. If there are no problems, the merge request will be accepted and the issue will be closed. Once your PR has been merged or rejected, you can delete your branch if you don't need it any more:
```
git branch -d issueXX
```
