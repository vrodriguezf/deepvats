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

# Python dependencies
tsai_data = import("tsai.data.all")
wandb = import("wandb")
pd = import("pandas")
hdbscan = import("hdbscan")
tchub = import_from_path("tchub.all", path=paste0(Sys.getenv("HOME")))

#############
# CONFIG #
#############

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
WANDB_PROJECT = "pacmel/tchub"


####################
# HELPER FUNCTIONS #
####################

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

vec_dyShading <- function(dyg, from, to, color, data_rownames) {
  
  # assuming that from, to, and color have all same length
  n <- length(from)
  if (n == 0) return(dyg)
  
  new_shades <- vector(mode = "list", length = n)
  for (i in 1:n) {
    new_shades[[i]] <- list(from = data_rownames[from[[i]]],
                            to = data_rownames[to[[i]]],
                            color = color,
                            axis = "x")
  }
  dyg$x$shadings <- c(dyg$x$shadings, new_shades)
  dyg
}

# Not used yet (it is likely to be used in the future)
make_individual_dygraph <- function(i){
  plt <- dygraph(tsdf()[i],height= "170",group = "timeseries", ylab = names(tsdf())[i],width="100%") %>%
    dySeries(color=color_scale_dygraph[i]) %>%
    dyHighlight(hideOnMouseOut = TRUE) %>%
    dyOptions(labelsUTC = TRUE) %>%
    dyLegend(show = "follow", hideOnMouseOut = TRUE) %>%
    dyUnzoom() %>%
    dyHighlight(highlightSeriesOpts = list(strokeWidth = 3)) %>%
    dyCSS(
      textConnection(
        "
                        .dygraph-ylabel {font-size: 9px; width: 80%;text-align: center;float: right} 
                        .dygraph-legend > span { display: none; }
                        .dygraph-legend > span.highlight { display: inline; }"
      )
    )
  if(i==1){
    plt <-plt %>%
      dyRangeSelector(height = 20, strokeColor = "")
  }
  plt
}


##############################################
# RETRIEVE WANDB RUNS & ARTIFACTS #
##############################################

api <- wandb$Api()

print("Querying encoders")
encs_l <- tchub$get_wandb_artifacts(project_path = "pacmel/tchub", type = "learner", 
                                 last_version=F) %>% 
  discard(~ is_empty(.$aliases) | is_empty(.$metadata$valid_artifact))
encs_l <- encs_l %>% set_names(encs_l %>% map(~ glue("pacmel/tchub/", .$name)))

# embs_l <- tchub$get_wandb_artifacts(project_path = "pacmel/tchub", type = "object",
#                                     name="embeddings", last_version=F) %>%
#   discard(~ is_empty(.$aliases))
# embs_l <- embs_l %>% set_names(embs_l %>% map(~.$aliases))
#encs_l <- embs_l %>% map(~.$metadata$enc_artifact) %>% str_split("/") %>% map(pluck(3))
#dsets_l <- embs_l %>% map(~.$metadata$input_ar) %>% str_split("/") %>% map(pluck(3))
print("Done!")
