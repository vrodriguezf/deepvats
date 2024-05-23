# Dependencies
source("./dependencies.R")
options(shiny.trace = TRUE, shiny.loglevel = "DEBUG")
# Logs handling and configuration
source("./lib/global/logs.R")
source("./lib/global/plots.R")

##########
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