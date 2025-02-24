options(scipen = 999) #Show decimals, no scientific notation (for logs)

#####################
# GLOBAL VARIABLES  #
#####################
### Log variables
toguether = TRUE

user <- Sys.getenv("USER")
#user <- system("id -un", intern = TRUE)
data_path <- file.path("/home", user, "data")

header <-"r_shiny_app_logs"
id_file <- file.path(data_path, header, "execution_id")

### Debug variables
DEBUG_LEVEL <- 15 # Logged Group >= DEBUG_LEVEL
FILE_FLAG   <- TRUE
LOG_PATH    <- ""
LOG_HEADER  <- ""
DEBUG_GROUPS<- list (
  'generic' = 0,
  'main'    = 1,
  'button'  = 2,
  'embs'    = 4,
  'time'    = 11,
  'matrix'  = 9,
  'tmi'     = 12,
  'force'   = -1,
  'error'   = -1,
  'debug'   = 11,
  'react'   = 2,
  'js'      = 10,
  'cache'   = 10,
  'proc'    = 12
) 
MAX_CHARS   <- 65

message_header <- function(mssg, mssg_id, add_header, header, time) {
  if (add_header) {
    formated_mssg = paste0(time, " [", mssg_id, "] ", header, " || ", mssg, "\n")
  } else {
    formated_mssg = paste0(time, " [", mssg_id, "] ", mssg, "\n")
  }
  #print(paste0("formated", formated_mssg))
  return(formated_mssg)
}
message_split_single <- function(mssg, max_chars = MAX_CHARS) {
  n <- ceiling(nchar(mssg) / max_chars)
  start <- seq(1, by = max_chars, length.out = n)
  end <- pmin(start + max_chars - 1, nchar(mssg))
  #print(paste0("Split || Total messages: ", n))
  splitted_mssg <- substring(
      mssg, 
      first = start, 
      last  = end
  )
  #print(paste0("Split || Start indices: ", paste(start, collapse = ", ")))
  #print(paste0("Split || End indices: ", paste(end, collapse = ", ")))
  #print(paste0("Split || Splitted fragments: ", paste(splitted_mssg, collapse = " | ")))
  return(splitted_mssg)
}
message_split <- function(mssg, max_chars = MAX_CHARS) {
  if (is.list(mssg) || is.vector(mssg)){
    mssg_split <- ""
    for ( i in seq_along(mssg)){
      mssg_split <- c(mssg_split, message_split_single(mssg[[i]]))
    }
  } else {
      mssg_split <- message_split_single(mssg)
  }
  return (mssg_split)
}
log_to_file <- function(
  formated_mssg,
  file_flag,
  file_path, 
  collapse = ' '
){
  if (file_flag && !is.null(file_path)) {
    if (file_path != "") {
      file_path = paste0 ("../data/", file_path)
      if (!file.exists(file_path)) {
        file.create(file_path)
      }
      cat(
        paste(formated_mssg, collapse = collapse),
         file = file_path, 
         append = TRUE, 
         collapse = ''
      )
    }
  }
}


log_print   <- local({
  MESSAGE_ID <- 0
  function(
    mssg, 
    file_flag     = FILE_FLAG, 
    file_path     = LOG_PATH, 
    log_header    = LOG_HEADER,
    debug_level   = DEBUG_LEVEL,
    debug_group   = 'generic',
    add_header    = TRUE,
    max_chars     = MAX_CHARS
  ) {
      debug_group_id = DEBUG_GROUPS[[debug_group]]

      if (debug_group_id == -1 || debug_group_id <= debug_level){
          time <- format(Sys.time(), "%H:%M:%OS3")
          MESSAGE_ID <<- MESSAGE_ID + 1
          formated_mssg <- message_header(
            mssg        = mssg, 
            mssg_id     = MESSAGE_ID, 
            add_header  = add_header, 
            header      = log_header, 
            time        = time
          )
          formated_mssg <- message_split(formated_mssg, max_chars)
          cat(
            paste(formated_mssg, collapse = paste0("\n ", time, " [", MESSAGE_ID, "] ")), 
            collapse = ''
          )
          log_to_file(formated_mssg, file_flag, file_path)
      }
      flush.console()
  }
})

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
  if (is.null(time)) {log_print("Time is empty! Check it out", debug_group = 'force')}
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
  log_print(paste0("Log add | ", function_), debug_group = 'time')
  new_mssg = rbind(log_mssg, new_mssg)
  #print("log add --- mssg ---")
  #print(new_mssg)
  #print("--- log add --- mssg ---")
  return(new_mssg) 
}
