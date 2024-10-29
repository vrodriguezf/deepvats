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

get_ts_plot_name <- function(dataset_name, encoder_name, prj_plot_id, input){
    print("Getting timeserie plot name")
    plt_name <- paste0(dataset_name,  "_", encoder_name, input$dr_method, "_ts.html")
    print(paste0("ts plot name: ", plt_name))
    plt_name
}

get_window_indices_ <- function(prjs, wlen, stride) {
    log_print(paste0("|| get_window_indices_ || prjs ~", dim(prjs)))
    log_print(paste0("|| get_window_indices_ || wlen", wlen))
    log_print(paste0("|| get_window_indices_ || stride", stride))
    window_indices <- sapply(prjs, function(idx) {
        #start_idx <- floor((idx - 1) / stride) * stride + 1
        #seq(start_idx, start_idx + wlen - 1)
        start_idx <- ((idx-1)*stride) + 1
        seq(start_idx, start_idx + wlen)
    })
    res <-  unique(unlist(window_indices))
    log_print(paste0("|| get_window_indices_ || window_indices ~", length(res)))
    res
}