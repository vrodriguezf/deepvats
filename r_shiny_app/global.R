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
library(profvis)

reactlog::reactlog_enable()

options(scipen = 999) #Show decimals, no scientific notation (for logs)

#options(shiny.trace = TRUE, shiny.loglevel = "DEBUG", shiny.app_log_path = "app/shiny_logs_internal")

torch <- reticulate::import("torch")
#options(shiny.trace = TRUE)
if(torch$cuda$is_available()){
  print(paste0("CUDA AVAILABLE. Num devices: ", torch$cuda$device_count()))
  torch$cuda$set_device(as.integer(0))
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
WANDB_ENTITY = Sys.getenv("WANDB_ENTITY")
WANDB_PROJECT = Sys.getenv("WANDB_PROJECT")


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

log_print <- function(mssg, file_flag = FALSE, file_path = "", log_header = "") {
  time <- format(Sys.time(), "%H:%M:%OS3")
  formated_mssg = paste0(time, "::::", log_header, "::::", mssg, "\n")
  print(formated_mssg)
  if (file_flag && file_path != "") {
    file_path = paste0 ("../data/", file_path)
    if (!file.exists(file_path)) {
      file.create(file_path)
    }
    cat(formated_mssg, file = file_path, append = TRUE)
  }
}

log_add <- function(
  log_mssg, 
  function_,
  cpu_flag,
  dr_method,
  clustering_options,
  zoom,
  mssg, 
  time
) {
  if (is.null(time)) {print("Time is empty! Check it out")}
  timestamp = format(as.POSIXct(Sys.time(), origin = "1970-01-01"), "%Y-%m-%d %H:%M:%OS3")
  new_mssg = data.frame(
    timestamp           = timestamp,
    function_           = function_,
    cpu_flag            = cpu_flag,
    dr_method           = dr_method,
    clustering_options  = clustering_options,
    zoom                = ifelse(is.null(zoom), FALSE, zoom),
    time                = ifelse(is.null(time), 0, time),
    mssg                = ifelse(is.null(mssg), "", mssg),
    stringsAsFactors    = FALSE  # Evitar factores
  )
  print(paste0("Log add | ", function_))
  new_mssg = rbind(log_mssg, new_mssg)
  return(new_mssg) 
}

get_execution_id <- function(file) {
  if (file.exists(file)) {
    df = feather::read_feather(file)
    if (!all(c("id", "timestamp") %in% colnames(df))) {
      stop("Wrong Execution ID feather file")
    }
      id = max(as.numeric(df$id)) + 1
  } else {
    id = 1
    df = data.frame(id = numeric(0), timestamp = character(0))
  }
  timestamp = format(Sys.time(), "%d/%m/%y %H:%M:%S")
  record = data.frame(id = id, timestamp=timestamp)
  df = rbind(df, record)
  feather::write_feather(df, file)
  log_print(paste0("Execution id: ", id, ", Start Timestamp: ", timestamp))
  return(id)
}

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


toguether = TRUE
header = "r_shiny_app_logs"
id_file = "execution_id"