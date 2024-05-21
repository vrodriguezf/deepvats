 logMessages <- reactiveVal("")
    send_log <- function(message) {
        print("--> Log message")
        new_log = paste0(logMessages(), Sys.time(), " - ", message, "\n")
        logMessages(new_log)
        #print(new_log)
        invalidateLater(10, session)
        print(paste0("Log Message |  ", message, "-->"))
    }