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
  'main' = 1
)