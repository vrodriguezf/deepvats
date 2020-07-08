library(shiny)
library(reticulate)
library(purrr)
library(jsonlite)
library(tibble)
library(ggplot2)
library(shinycssloaders)
library(tidyr)
library(dplyr)

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

embeddings = py_load_object(filename = "/data/PACMEL-2019/wandb_artifacts/5630535579917677987") %>% as.data.frame
colnames(embeddings) = c("xcoord", "ycoord")
tsdf = py_load_object(filename = "/data/PACMEL-2019/wandb_artifacts/7087224962096418705") %>% 
  rownames_to_column("Time") %>% 
  mutate(Time=as.POSIXct(Time))
View(embeddings)

w = 36
s = 1

###
# HELPER FUNCTIONS
###
get_window_indices = function(i, w, s) {
  start_index = ((i-1)*s + 1)
  return(start_index:(start_index+w-1))
}
