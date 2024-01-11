logMessages <- reactiveVal("")
send_log <- function(message, session) {
    new_log = paste0(logMessages(), Sys.time(), " - ", message, "\n")
    logMessages(new_log)
    invalidateLater(10, session)
}