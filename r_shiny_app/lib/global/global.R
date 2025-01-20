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
#options(shiny.trace = TRUE, shiny.loglevel = "DEBUG", error=browser)
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



#############
# CONFIG #
#############

QUERY_RUNS_LIMIT = 1
DEFAULT_PATH_WANDB_ARTIFACTS = paste0(Sys.getenv("HOME"), "/data/wandb_artifacts")
hdbscan_metrics <- hdbscan$dist_metrics$METRIC_MAPPING
#hdbscan_metrics <- c('euclidean', 'l2', 'l1', 'manhattan', 'cityblock', 'braycurtis', 'canberra', 'chebyshev', 'correlation', 'cosine', 'dice', 'hamming', 'jaccard', 'kulsinski', 'mahalanobis', 'matching', 'minkowski', 'rogerstanimoto', 'russellrao', 'seuclidean', 'sokalmichener', 'sokalsneath', 'sqeuclidean', 'yule', 'wminkowski', 'nan_euclidean', 'haversine')
Sys.setenv("TZ"="UTC")
#DEFAULT_VALUES = list(metric_hdbscan = "euclidean",
#                      min_cluster_size_hdbscan = 100,
#                      min_samples_hdbscan = 15,
#                      cluster_selection_epsilon_hdbscan = 0.08,
#                      path_line_size = 0.08,
#                      path_alpha = 0.01,
#                      point_alpha = 1,
#                      point_size = 1.25)
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
    name    = "Unzoom",
    path    = system.file("plugins/unzoom.js", package = "dygraphs")
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
  return(id)
}

# Check if an element is enabled or not
jsCode <- '
shinyjs.checkEnabled = function(id) {
  console.log("ID:", id);  // Imprimir ID en la consola del navegador
  var isEnabled = !document.getElementById(id).hasAttribute("disabled");
  console.log("Is Enabled:", isEnabled);  // Imprimir el estado de habilitación
  Shiny.setInputValue(id + "_enabled", isEnabled);
  console.log("Shiny input updated:", id + "_enabled");  // Confirmación de actualización
}
'
#Cuidado, poner print en jsCode te abre la ventana de imprimir de ctrl+P