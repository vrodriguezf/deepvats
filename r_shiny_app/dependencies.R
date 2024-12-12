# R dependencies
library(shiny)
library(shinyjs)
library(shinycssloaders)
library(shinyWidgets)

library(reticulate)
library(purrr)
library(jsonlite)
library(tibble)
library(ggplot2)
library(glue)

library(tidyr)
library(data.table)
library(dplyr)
library(dygraphs)

library(RColorBrewer)
library(pals)
library(stringr)
#library(reactlog)
library(feather)
library(arrow)
library(fasttime)
library(parallel)
library(xts)
#library(profvis)
#reactlog::reactlog_enable()
library(semantic.dashboard)
library(htmlwidgets)
library(randomcoloR)
library(farver)

# Cargar librerías de Python necesarias
sklearn <- import("sklearn")
statsmodels <- import("statsmodels.api")
scipy <- import("scipy")

#options(shiny.trace = TRUE, shiny.loglevel = "DEBUG", shiny.app_log_path = "app/shiny_logs_internal")

torch <- reticulate::import("torch")
momentfm <- reticulate::import("momentfm")
ft <- reticulate::import("pyarrow.feather")


#options(shiny.trace = TRUE)
if(torch$cuda$is_available()){
  print(paste0("CUDA AVAILABLE. Num devices: ", torch$cuda$device_count()))
  #torch$cuda$set_device(as.integer(0))
  torch$cuda$set_device(as.integer(1))
  #torch$cuda$set_device(as.integer(2))
  #print(torch$cuda$memory_summary())
  print(Sys.getenv("PYTORCH_CUDA_ALLOC_CONF"))
} else {
  print("CUDA NOT AVAILABLE")
}

# Python dependencies
tsai_data = reticulate::import("tsai.data.all")
wandb = reticulate::import("wandb")
pd = reticulate::import("pandas")
hdbscan = reticulate::import("hdbscan")
np = reticulate::import("numpy")
dvats = reticulate::import_from_path("dvats.all", path=paste0(Sys.getenv("HOME")))
mplots = reticulate::import_from_path("dvats.mplots", path=paste0(Sys.getenv("HOME")))
utils = reticulate::import_from_path("dvats.utils", path = paste0(Sys.getenv("HOME")))
#print("--> py_config ")
#print(reticulate::py_config())
#print("py_config -->")