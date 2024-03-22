# R dependencies
library(shiny)
library(shinyjs)
library(reticulate)
library(purrr)
library(jsonlite)
library(tibble)
library(ggplot2)
library(glue)
library(shinycssloaders)
library(tidyr)
library(data.table)
library(dplyr)
library(dygraphs)
library(shinyWidgets)
library(RColorBrewer)
library(pals)
library(stringr)
##################QUITAR CUANDO YA TIRE
library(reactlog)
library(feather)
library(arrow)
library(fasttime)
library(parallel)
#library(shinythemes)
library(xts)
source("./global-helper-logs.R")


reactlog::reactlog_enable()
#options(shiny.trace = TRUE, shiny.loglevel = "DEBUG", shiny.app_log_path = "app/shiny_logs_internal")

torch <- reticulate::import("torch")
#options(shiny.trace = TRUE)
if(torch$cuda$is_available()){
  print(paste0("CUDA AVAILABLE. Num devices: ", torch$cuda$device_count()))
  torch$cuda$set_device(as.integer(1))
  #torch$cuda$set_device(as.integer(1))
  #torch$cuda$set_device(as.integer(2))
  #print(torch$cuda$memory_summary())
  print(Sys.getenv("PYTORCH_CUDA_ALLOC_CONF"))
} else {
  print("CUDA NOT AVAILABLE")
}
#################QUITAR CUANDO YA TIRE

# Python dependencies
#tsai_data = import("tsai.data.all")
#wandb = import("wandb")
#pd = import("pandas")
#hdbscan = import("hdbscan")
#dvats = import_from_path("dvats.all", path=paste0(Sys.getenv("HOME")))
############Just in case. Trying to get why get_enc_embs gets freezed
# Python dependencies
tsai_data = reticulate::import("tsai.data.all")
wandb = reticulate::import("wandb")
pd = reticulate::import("pandas")
hdbscan = reticulate::import("hdbscan")
dvats = reticulate::import_from_path("dvats.all", path=paste0(Sys.getenv("HOME")))


print("--> py_config ")
print(reticulate::py_config())
print("py_config -->")

#############
# CONFIG #
##########
QUERY_RUNS_LIMIT = 1
DEFAULT_PATH_WANDB_ARTIFACTS = paste0(Sys.getenv("HOME"), "/data/wandb_artifacts")
hdbscan_metrics <- hdbscan$dist_metrics$METRIC_MAPPING
#hdbscan_metrics <- c('euclidean', 'l2', 'l1', 'manhattan', 'cityblock', 'braycurtis', 'canberra', 'chebyshev', 'correlation', 'cosine', 'dice', 'hamming', 'jaccard', 'kulsinski', 'mahalanobis', 'matching', 'minkowski', 'rogerstanimoto', 'russellrao', 'seuclidean', 'sokalmichener', 'sokalsneath', 'sqeuclidean', 'yule', 'wminkowski', 'nan_euclidean', 'haversine')
Sys.setenv("TZ"="UTC")
DEFAULT_VALUES = list(metric_hdbscan = "euclidean",
                      min_cluster_size_hdbscan = 100,
                      min_samples_hdbscan = 15,
                      cluster_selection_epsilon_hdbscan = 0.08,
                      path_line_size = 0.08,
                      path_alpha = 5/10,
                      point_alpha = 1/10,
                      point_size = 1)
WANDB_ENTITY = Sys.getenv("WANDB_ENTITY")
WANDB_PROJECT = Sys.getenv("WANDB_PROJECT")

##############################################
# RETRIEVE WANDB RUNS & ARTIFACTS #
##############################################

api <- wandb$Api()

log_print("Querying encoders")
encs_l <- dvats$get_wandb_artifacts(
  project_path = glue(WANDB_ENTITY, "/", WANDB_PROJECT), 
                                    type = "learner", 
                                    last_version=F) %>% 
  discard(~ is_empty(.$aliases) | is_empty(.$metadata$train_artifact))
encs_l <- encs_l %>% set_names(encs_l %>% map(~ glue(WANDB_ENTITY, "/", WANDB_PROJECT, "/", .$name)))
  #discard(~ str_detect(.$name, "dcae"))

log_print("Done!")