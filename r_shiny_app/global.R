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
    if (!file.exists(file_path)) {
      file.create(file_path)
    }
    cat(formated_mssg, file = file_path, append = TRUE)
  }
}

log_add <- function(log_mssg, mssg, time, header) {
  new_mssg = data.frame(
    timestamp = Sys.time(), 
    time = time, 
    mssg =mssg, 
    header = header 
  )
  print(paste0("Log add", header))
  new_mssg = rbind(log_mssg, new_mssg)
  return(new_mssg) 
}



# Función para leer o inicializar el ID de ejecución
get_execution_id <- function(file) {
  if (file.exists(file)) {
    # Lee el ID actual y lo incrementa
    id = as.numeric(readLines(file)) + 1
  } else {
    # Inicializa el ID si el archivo no existe
    id = 1
  }
  # Guarda el ID actualizado en el archivo
  writeLines(as.character(id), file)
  print(paste0("Execution id: ", id))
  return(id)
}

##############################################
# RETRIEVE WANDB RUNS & ARTIFACTS #
##############################################

api <- wandb$Api()

log_print("Querying encoders")
encs_l <- dvats$get_wandb_artifacts(project_path = glue(WANDB_ENTITY, "/", WANDB_PROJECT), 
                                    type = "learner", 
                                    last_version=F) %>% 
  discard(~ is_empty(.$aliases) | is_empty(.$metadata$train_artifact))
encs_l <- encs_l %>% set_names(encs_l %>% map(~ glue(WANDB_ENTITY, "/", WANDB_PROJECT, "/", .$name)))
  #discard(~ str_detect(.$name, "dcae"))

log_print("Done!")


toguether = TRUE
header = "witc2024"
id_file = "execution_id.txt"