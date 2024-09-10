logMessages <- reactiveVal("")

send_log <- function(message, session) {
    new_log = paste0(logMessages(), Sys.time(), " - ", message, "\n")
    logMessages(new_log)
    invalidateLater(10, session)
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
  print(paste0("Log add | ", function_, " | ", mssg))
  if (is.null(time)) {print("Time is empty! Check it out")}
  timestamp = format(as.POSIXct(Sys.time(), origin = "1970-01-01"), "%Y-%m-%d %H:%M:%OS3")
  new_mssg = data.frame(
    timestamp           = timestamp,
    function_           = function_,
    cpu_flag            = ifelse(is.null(cpu_flag), FALSE, cpu_flag),
    dr_method           = ifelse(is.null(dr_method), "Undefined", dr_method), 
    clustering_options  = ifelse(is.null(clustering_options), "Undefined", clustering_options),
    zoom                = ifelse(is.null(zoom), FALSE, zoom),
    time                = ifelse(is.null(time), 0, time),
    mssg                = ifelse(is.null(mssg), "", mssg),
    stringsAsFactors    = FALSE 
  )
  print(paste0("Log add | ", function_, " | ", new_mssg))
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