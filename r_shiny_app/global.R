# R dependencies
library(shiny)
library(reticulate)
library(purrr)
library(jsonlite)
library(tibble)
library(ggplot2)
library(shinycssloaders)
library(tidyr)
library(dplyr)
library(dygraphs)

# Python dependencies
wandb = import("wandb")
pd = import("pandas")

###
# CONSTANTS
###
QUERY_RUNS_LIMIT = 1
DEFAULT_PATH_WANDB_ARTIFACTS = "/data/PACMEL-2019/wandb_artifacts"
#w = 36 # * TODO: This has to be dependant on the selected run! 
#s = 1 # * TODO: This has to be dependant on the selected run!

###
# HELPER FUNCTIONS
###
get_window_indices = function(idxs, w, s) {
  idxs %>% map(function (i) {
    start_index = ((i-1)*s + 1)
    return(start_index:(start_index+w-1))
  })
}

dyUnzoom <-function(dygraph) {
  dyPlugin(
    dygraph = dygraph,
    name = "Unzoom",
    path = system.file("plugins/unzoom.js", package = "dygraphs")
  )
}

###
# Retrieve wandb runs
###
api = wandb$Api()

print(paste0("Querying ", QUERY_RUNS_LIMIT, "runs..."))
runs_it = api$runs("vrodriguezf/timecluster-extension")
print("Processing runs...")
runs = purrr::rerun(QUERY_RUNS_LIMIT, iter_next(runs_it))

# Filter to keep only the dimensionality reduction runs, those that have a config parameter
# called "dcae_run_path" and whose state is "finished"
print("Filtering runs...")
runs = runs %>%
  keep(function(run) {
    # config = fromJSON(run$json_config)
    logged_artifacts = run$logged_artifacts()
    print(run$state)
    print(run$config$ds_artifact_name)
    return(
      run$state == "finished" &&
      !is.null(run$config$ds_artifact_name) && 
        !is.null(iter_next(logged_artifacts))
    )
  })

runs = runs %>% set_names(runs %>% map(~ .$name))
print(runs)

###
# Debug: Load embeddings and data for testing
###
foo = api$run("vrodriguezf/timecluster-extension/1cr4xkmp")
runs = list(foo) %>% set_names(foo$name)

# embeddings = py_load_object(filename = file.path(DEFAULT_PATH_WANDB_ARTIFACTS, "5630535579917677987")) %>% as.data.frame
# colnames(embeddings) = c("xcoord", "ycoord")
# tsdf = py_load_object(filename = "/data/PACMEL-2019/wandb_artifacts/7087224962096418705") %>% 
#   rownames_to_column("Time") %>% 
#   mutate(Time=as.POSIXct(Time))
#last_data_index = get_window_indices(idxs = nrow(embeddings), w = w, s = s)[[1]] %>% tail(1)
# tsdf = py_load_object(filename = "/data/PACMEL-2019/wandb_artifacts/7087224962096418705") %>% 
#   rownames_to_column("timeindex") %>% 
#   slice(1:last_data_index) %>% 
#   column_to_rownames(var = "timeindex")
  
#View(embeddings)

# default_tsplot <- dygraph(tsdf, main = "Original data (normalized)") %>%
#   dyRangeSelector() %>%   
#   dyHighlight(hideOnMouseOut = TRUE) %>% 
#   dyOptions(labelsUTC = TRUE) %>% 
#   dyLegend(show="follow", hideOnMouseOut = TRUE) %>% 
#   dyUnzoom() %>% 
#   dyHighlight(highlightSeriesOpts = list(strokeWidth = 3)) %>%
#   dyCSS(textConnection("
#      .dygraph-legend > span { display: none; }
#      .dygraph-legend > span.highlight { display: inline; }
#   "))
