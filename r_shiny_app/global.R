# R dependencies
library(shiny)
library(shinyjs)
library(reticulate)
library(purrr)
library(jsonlite)
library(tibble)
library(ggplot2)
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
wandb = import("wandb")
pd = import("pandas")
hdbscan = import("hdbscan")


#############
# CONSTANTS #
#############

QUERY_RUNS_LIMIT = 150
DEFAULT_PATH_WANDB_ARTIFACTS = "/data/PACMEL-2019/wandb_artifacts"
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


#######################
# RETRIEVE WANDB RUNS #
#######################

api <- wandb$Api()

embeddings_filter = dict("$and"=list(dict("jobType"="dimensionality_reduction",
                                          "config.emb_artifact_name"="embeddings",
                                          "state"="finished")))

print("Querying runs...")
runs_it <- api$runs("pacmel/timecluster-extension", filters=embeddings_filter)

print("Processing runs...")
runs <- purrr::rerun(QUERY_RUNS_LIMIT, iter_next(runs_it))
runs <- runs %>% set_names(runs %>% map(~.$name)) %>% compact()


###############################################
# DEBUG: Load embeddings and data for testing #
###############################################

# foo = api$run("pacmel/timecluster-extension/3jvuv2s3")
# runs = list(foo) %>% set_names(foo$name)

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
