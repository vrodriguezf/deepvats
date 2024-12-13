# Description:
# This file provides utilities to streamline the management of logging configurations 
# for reactive and observer functions in an R Shiny application. It centralises the 
# setup of logging parameters (`observe_configs`) and ensures consistent usage across 
# the application.

# Sections:
# - Operators: Defines reusable operators like `%||%` for default value handling.
# - Default Parameters: Contains a centralised list (`observe_configs`) defining 
#   default headers (`hd`) and debug groups (`dg`) for each reactive/observe/observeEvent function.
# - Parameters Update & Local Log Definition: Includes the `setup_log_print` function, 
#   which dynamically configures a dictionary of localised logging functions (`lps`, `lpe`, `lp`) 
#   with default and customisable parameters.

# Guidelines for Maintenance:
# - Always add new reactive/observe/observeEvent identifiers to
#   the `observe_configs` list with appropriate defaults (`hd` and `dg`).
# - Ensure `setup_log_print` is used to dynamically configure the logging functions 
#   (`lps`, `lpe`, `lp`) for consistent logging across the application.
# - Keep the `observe_configs` list organised and well-documented to improve clarity 
#   and maintainability for all developers.

# Notes:
# - The `%||%` operator provides a shorthand for handling default values.
# - Use the returned logging functions (`lps`, `lpe`, `lp`) within reactive contexts, 
#   and pass additional arguments (`...`) to accommodate custom behaviours.

source("~/app/lib/global/logs.R")

# Operators
`%||%` <- function(a, b) {
    if (!is.null(a)) {
        a 
    } else if (!is.null(b))
    {
        b
    } else {
        'debug'
    }
}
`%<-%` <- function(vars, value) {
    var_names <- as.list(substitute(vars))[-1L]  # Extraer nombres de variables
    if (length(var_names) != length(value)) {
        stop("Number of variables does not match the number of values.")
    }
    for (i in seq_along(var_names)) {
        assign(as.character(var_names[[i]]), value[[i]], envir = parent.frame())
    }
    invisible(NULL)
}

# Default parameters
observe_configs <- list(
    'opd' = list(
        hd = 'observe preprocess dataset', 
        dg = 'react'
    )
)

# Parameters update & local log functions definition
setup_log_print <- function(
    event_name, debug_group = NULL, ...
) {
    if (!event_name %in% names(observe_configs)) {
        stop(paste("Event name not found in observe_configs:", event_name))
    } else{

    }
    config <- observe_configs[[event_name]]
    debug_group <- debug_group %||% config$dg
    observe_configs[[event_name]]$dg <- debug_group
    if (is.null(debug_group)) {
        stop("debug_group is NULL after resolution.")
    } #else {
      #  message(paste0("Resolved debug_group for event '", event_name, "': ", debug_group))
    #}
    # Log start
    lps <- function(
        header = config$hd, debug_group = observe_configs[[event_name]]$dg, ...
    ) {
       # message(paste0("lps | Debug group ", observe_configs[[event_name]]$dg))
        log_print(
            paste0("--> ", header),
            debug_group = debug_group,
            ...
        )
    }
    
    # Log end
    lpe <- function(
        header = config$hd, debug_group = observe_configs[[event_name]]$dg, ...
    ) {
        log_print(
            paste0(header, " -->"),
            debug_group = debug_group,
            ...
        )
    }
    
    
    # Log message
    lp <- function(
        mssg, header = config$hd, debug_group = observe_configs[[event_name]]$dg, ...
    ) { 
        log_print(
            paste0(header, " || ", mssg),
            debug_group = debug_group,
            ...
        )
    }
    # Test lps, lpe, lp
    #lps()
    #lpe()
    #lp("Hola")
    #message(paste0("Tested lpe lps lpb for ", event_name))
    # Return a dictionary of logging functions
    return(list(lps = lps, lpe = lpe, lp = lp))
}
