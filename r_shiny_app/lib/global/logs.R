options(scipen = 999) #Show decimals, no scientific notation (for logs)

#####################
# GLOBAL VARIABLES  #
#####################
### Log variables
toguether = TRUE

user <- Sys.getenv("USER")
data_path <- file.path("/home", user, "data")

header <-"r_shiny_app_logs"
id_file <- file.path(data_path, header, "execution_id")

### Debug variables
DEBUG_LEVEL <- 1 # Logged Group >= DEBUG_LEVEL
FILE_FLAG   <- FALSE
LOG_PATH    <- ""
LOG_HEADER  <- ""
DEBUG_GROUPS<- list (
  'generic' = 0,
  'main'    = 1,
  'button'  = 2,
  'embs'    = 1,
  'time'    = 8,
  'matrix'  = 9,
  'tmi'     = 10,
  'force'   = -1,
  'error'   = -1,
  'debug'   = 11
)

log_print <- function(
  mssg, 
  file_flag     = FILE_FLAG, 
  file_path     = LOG_PATH, 
  log_header    = LOG_HEADER,
  debug_level   = DEBUG_LEVEL,
  debug_group   = 'generic'
) {
    debug_group_id = DEBUG_GROUPS[[debug_group]]
    
    if (debug_group_id == -1 || debug_group_id <= debug_level){
        time <- format(Sys.time(), "%H:%M:%OS3")
        formated_mssg = paste0(time, "::::", log_header, "::::", mssg, "\n")
        cat(formated_mssg)
        if (file_flag && !is.null(file_path)) {
            if (file_path != "") {
                file_path = paste0 ("../data/", file_path)
                if (!file.exists(file_path)) {
                    file.create(file_path)
                }
                cat(formated_mssg, file = file_path, append = TRUE)
            }
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
  if (is.null(time)) {log_print("Time is empty! Check it out")}
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
  log_print(paste0("Log add | ", function_, debug_group = 'time'))
  new_mssg = rbind(log_mssg, new_mssg)
  return(new_mssg) 
}
