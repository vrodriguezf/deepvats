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
wandb = import("wandb")
api = wandb$Api()

# print("Querying runs...")
# runs_it = api$runs("vrodriguezf/timecluster-extension")
# print("Processing runs...")
# runs = iterate(runs_it)
# 
# # Filter to keep only the dimensionality reduction runs, those that have a cofnig parameter 
# # called "dcae_run_path" and whose state is "finished"
# print("Filtering runs...")
# runs = runs %>% 
#   keep(function(run) {
#     config = fromJSON(run$json_config)
#     return(!is.null(config$dcae_run_path))
#   })
# 
# runs = runs %>% set_names(runs %>% map(~ .$name))
# print(runs)

###
# Debug: Load embeddings and data for testing
###

w = 36
s = 1


embeddings = py_load_object(filename = "/data/PACMEL-2019/wandb_artifacts/5630535579917677987") %>% as.data.frame
colnames(embeddings) = c("xcoord", "ycoord")
# tsdf = py_load_object(filename = "/data/PACMEL-2019/wandb_artifacts/7087224962096418705") %>% 
#   rownames_to_column("Time") %>% 
#   mutate(Time=as.POSIXct(Time))
last_data_index = get_window_indices(idxs = nrow(embeddings), w = w, s = s)[[1]] %>% tail(1)
tsdf = py_load_object(filename = "/data/PACMEL-2019/wandb_artifacts/7087224962096418705") %>% 
  rownames_to_column("timeindex") %>% 
  slice(1:last_data_index) %>% 
  column_to_rownames(var = "timeindex")

# auxiliary object for the interaction ts->embeddings
tsidxs_per_embedding_idx <- get_window_indices(1:nrow(embeddings), w=w, s=s)
  
#View(embeddings)

default_tsplot <- dygraph(tsdf, main = "Original data (normalized)") %>%
  dyRangeSelector() %>%   
  dyHighlight(hideOnMouseOut = TRUE) %>% 
  dyOptions(labelsUTC = TRUE) %>% 
  dyLegend(show="follow", hideOnMouseOut = TRUE) %>% 
  dyUnzoom() %>% 
  dyHighlight(highlightSeriesOpts = list(strokeWidth = 3)) %>%
  dyCSS(textConnection("
     .dygraph-legend > span { display: none; }
     .dygraph-legend > span.highlight { display: inline; }
  "))
