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
debug_level = 0 # Logged Group >= DEBUG_LEVEL
debug_groups = list (
  'generic' = 0,
  'main' = 1
)

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