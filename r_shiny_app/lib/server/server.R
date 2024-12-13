source("./lib/server/preprocessing.R")
source("./lib/server/utils.R")
# Function for parallel timeindex conversion
parallel_posfix <- function(df) {
    chunk_size = 100000
    num_chunks = ceiling(nrow(df)/chunk_size)
    chunks=split(df$timeindex, ceiling(seq_along(df$timeindex)/chunk_size))
            
    print(paste0("Parallel posfix | Chunks: ", num_chunks))
    cl = parallel::makeCluster(4)
    parallel::clusterEvalQ(cl, library(fasttime))
            
    print(paste0("Parallel posfix | Cluster ", cl, " of ", detectCores()))
    flush.console()
    
    result <- parallel::clusterApply(cl, chunks, function(chunk) {
        cat("Processing chunk\n")
        flush.console()
        #fasttime::fastPOSIXct(chunk, format = "%Y-%m-%d %H:%M:%S")
        as.POSIXct(chunk)
    })
    stopCluster(cl)
    print(" Reactive tsdf | Make conversion -->")
    print(" Reactive tsdf | Make conversion ")
    flush.console()
    return(unlist(result))
}

# Get next index for the projection plot
set_plot_id <- function(prj_plot_id)({
    prj_plot_id(prj_plot_id()+1)
})

# Get projection plot name
get_prjs_plot_name <- function(dataset_name, encoder_name, selected, cluster, prj_plot_id, input){
    set_plot_id()
    plt_name <- paste0(
        execution_id, "_",
        prj_plot_id(), "_",
        dataset_name, "_", 
        encoder_name, "_", 
        input$cpu_flag, "_", 
        input$dr_method, "_",  
        input$clustering_options, "_", 
        "zoom", "_", 
        input$zoom_btn, "_", 
        "point_alpha_",
        input$point_alpha, "_",
        "show_lines_",
        input$show_lines, "_",
        "prjs.png"
    )
    print(paste0("embeddings plot name", plt_name))
    plt_name
}

get_ts_plot_name <- function(
    dataset_name, 
    encoder_name, 
    prj_plot_id, 
    input
){
    log_print("--> get_ts_plot_name", debug_group = 'main')
    plt_name <- paste0(dataset_name,  "_", encoder_name, input$dr_method, "_ts.html")
    log_print(paste0("ts plot name: ", plt_name), debug_group = 'main')
    log_print("get_ts_plot_name -->", debug_group = 'main')
    plt_name
}

get_window_indices_ <- function(
    prjs, 
    wlen, 
    stride,
    log_path,
    log_header
) {
    res <- c()
    req(prjs)
    req(length(prjs) > 0, wlen > 0, stride > 0)
    kwargs <- list(
        file_path   = log_path,
        log_header  = log_header,
        debug_group = "embs"
    )

    # Llamar a log_print con diferentes mensajes usando do.call
    do.call(log_print, c(list(mssg = paste0("|| get_window_indices_ || prjs ~", length(prjs))), kwargs))    
    do.call(log_print, c(list(mssg = paste0("|| get_window_indices_ || wlen ", wlen)), kwargs))
    do.call(log_print, c(list(mssg = paste0("|| get_window_indices_ || stride ", stride)), kwargs))
    window_indices <- c()
    for (idx in prjs){
        start_idx <- ((idx-1)*stride)+1
        end_idx <- start_idx + wlen -1
        do.call(log_print, c(list(mssg = paste0("|| get_window_indices_ || sd ", start_idx)), kwargs))
        indices <- unlist(seq(start_idx, end_idx))
        log_print(paste0("|| get_window_indices_ || idx ", idx, " sd ", start_idx, " ed ", end_idx), debug_group = 'tmi')
        window_indices <- c(window_indices, indices)
    }
    res <- unique(window_indices)
    do.call(log_print, c(list(mssg = paste0("|| get_window_indices_ || window_indices ~", res)), kwargs))
    res
}

concat_preprocessed <- function(
    dataset                 = NULL,
    dataset_preprocessed    = NULL,
    ts_variables_selected   = NULL
){
    log_print("--> concat preprocessed", debug_group = 'main')
    dataset_combined <- dataset
    on.exit(log_print(paste0("concat preprocessed --> || colnames ", paste(colnames(dataset_combined), collapse = ', ')), debug_group = 'main'))
    if (!is.null(dataset_preprocessed) && ! is.null(dataset)) {
        log_print("concat preprocessed || Concat", debug_group = 'debug')
        dataset_combined <- concat_datasets(
            dataset1        = dataset,
            dataset2        = dataset_preprocessed,
            vars_dataset1   = NULL,
            vars_dataset2   = ts_variables_selected,
            suffix1         = NULL,
            suffix2         = "_preprocessed"
        )
        
    }

    return(dataset_combined)
}

reactiveVal_compute_or_cached <- function(
    object,
    params_prev,
    params_now,
    compute_function_name
){
    compute_flag <- FALSE
    header <- paste0("|| reactiveVal_compute_or_cached || ", compute_function_name, " || ")
    log_print(paste0("-->", header), debug_group = 'cache')
    on.exit(log_print(paste0(header, " compute? ", compute_flag, "-->"), debug_group = 'cache'))
    if ( is.null( object() ) || ! identical( params_prev, params_now ) ) {
        shinyjs::enable(compute_function_name)
        compute_flag <- TRUE
        if ( is.null( object() )){
            log_print(paste0(header, "First embedding computation, skipping cache"), debug_group = 'debug')
        } else {
            log_print(paste0(header, "At least 1 param changed"), debug_group = 'debug')
            different_params <- names(params_now)[
                sapply(
                    names(params_now), 
                    function(name) !identical(params_now[[name]], params_prev[[name]])
                )
            ]
            for (param in different_params){
                old_value <- params_prev[[param]]
                new_value <- params_now[[param]]
                log_print(sprintf("|| %s || | %-10s | Old: %-20s | New: %-20s |", header, param, old_value, new_value), debug_group = 'debug')
            }
        }
        shinyjs::disable(compute_function_name)
    } else {
        log_print(paste0(header, " Use cached || params_prev ", paste(params_prev, collapse = ', ')), debug_group = 'debug')
        log_print(paste0(header, " Use cached || params_prev ", paste(params_now, collapse = ', ')), debug_group = 'debug')
        log_print(paste0(header, " Use cached || null? ", is.null( object() ), " || compute? || ", compute_flag ), debug_group = 'debug')
    }
    return ( compute_flag )
}
