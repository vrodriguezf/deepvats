options(scipen = 999) #Show decimals, no scientific notation (for logs)

#####################
# GLOBAL VARIABLES  #
#####################
### Log variables
toguether = TRUE
header = "r_shiny_app_logs"
id_file = "execution_id"

### Debug variables
debug_level = 0 # Logged Group >= DEBUG_LEVEL
debug_groups = list (
  'generic' = 0,
  'buttons' = 1,
  'plots'   = 2
)

#############
# FUNCTIONS #
#############

log_print <- function(
  mssg, 
  file_flag = FALSE, 
  file_path = "", 
  log_header = "",
  debug_level = 0,
  debug_group = 'generic'
) {
  debug_group_id = debug_groups[[debug_group]]
  if (debug_group_id >= debug_level){
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