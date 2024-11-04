# Dependencies
source("./dependencies.R")
## -- Un comment for printing shiny logs
#options(shiny.trace = TRUE, shiny.loglevel = "DEBUG")
#options(shiny.error = browser, shiny.sanitize.errors = FALSE, shiny.fullstacktrace = TRUE)

# Logs handling and configuration
source("./lib/global/wandb.R")
source("./lib/global/logs.R")
source("./lib/global/plots.R")

##########
# CONFIG #
##########
QUERY_RUNS_LIMIT = 1
UPDATE_WANDB_ARTIFACTS = TRUE
DEFAULT_PATH_WANDB_ARTIFACTS = paste0(Sys.getenv("HOME"), "/data/wandb_artifacts")
hdbscan_metrics <- hdbscan$dist_metrics$METRIC_MAPPING
#hdbscan_metrics <- c('euclidean', 'l2', 'l1', 'manhattan', 'cityblock', 'braycurtis', 'canberra', 'chebyshev', 'correlation', 'cosine', 'dice', 'hamming', 'jaccard', 'kulsinski', 'mahalanobis', 'matching', 'minkowski', 'rogerstanimoto', 'russellrao', 'seuclidean', 'sokalmichener', 'sokalsneath', 'sqeuclidean', 'yule', 'wminkowski', 'nan_euclidean', 'haversine')
Sys.setenv("TZ"="UTC")
DEFAULT_VALUES = list(
  metric_hdbscan                    = "euclidean",
  min_cluster_size_hdbscan          = 100,
  min_samples_hdbscan               = 15,
  cluster_selection_epsilon_hdbscan = 0.08,
  path_line_size                    = 0.08,
  path_alpha                        = 2/10, #5/10,
  point_alpha                       = 1, #1/10,
  point_size                        = 1.25 #1
)
WANDB_ENTITY  = Sys.getenv("WANDB_ENTITY")
WANDB_PROJECT = Sys.getenv("WANDB_PROJECT")

##############################################
# RETRIEVE WANDB RUNS & ARTIFACTS #
##############################################

api <- wandb$Api()
encs_l_path <- path.expand("~/data/r_shiny_app_logs/encs_l.pickle")
data_l_path <- path.expand("~/data/r_shiny_app_logs/data_l.pickle")

if (UPDATE_WANDB_ARTIFACTS) {
  downloaded <- download_and_write_data(encs_l_path, data_l_path)
  encs_l <- downloaded[['encs_l']]
  data_l <- downloaded[['data_l']]
} else {
  tryCatch({
    encs_l <- py_load_object(encs_l_path)
    data_l <- py_load_object(data_l_path)
  }, error = function(e) {
    message("Could not read from local files, downloading and saving...")
    download_and_write_data(encs_l_path, data_l_path)
  })
}

encs_names <- sapply(encs_l, function(art) art$name)

log_print(
  paste0("Available encoders: ", encs_names),
  debug_group = 'tmi'
)

# Add here any zero-shot model you may want to use
zero_shot_models <- c("moment", "moirai")