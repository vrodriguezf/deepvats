# Function for parallel timeindex conversion
parallel_posfix <- function(df) {
    chunk_size = 100000
    num_chunks = ceiling(nrow(df)/chunk_size)
    chunks=split(df$timeindex, ceiling(seq_along(df$timeindex)/chunk_size))
            
<<<<<<< HEAD
    log_print(paste0("Parallel posfix | Chunks: ", num_chunks))
    cl = parallel::makeCluster(4)
    parallel::clusterEvalQ(cl, library(fasttime))
            
    log_print(paste0("Parallel posfix | Cluster ", cl, " of ", detectCores()))
=======
    print(paste0("Parallel posfix | Chunks: ", num_chunks))
    cl = parallel::makeCluster(4)
    parallel::clusterEvalQ(cl, library(fasttime))
            
    print(paste0("Parallel posfix | Cluster ", cl, " of ", detectCores()))
>>>>>>> master
    flush.console()
    
    result <- parallel::clusterApply(cl, chunks, function(chunk) {
        cat("Processing chunk\n")
        flush.console()
        #fasttime::fastPOSIXct(chunk, format = "%Y-%m-%d %H:%M:%S")
        as.POSIXct(chunk)
    })
    stopCluster(cl)
<<<<<<< HEAD
    log_print(" Reactive tsdf | Make conversion -->")
    log_print(" Reactive tsdf | Make conversion ")
=======
    print(" Reactive tsdf | Make conversion -->")
    print(" Reactive tsdf | Make conversion ")
>>>>>>> master
    flush.console()
    return(unlist(result))
}

# Get next index for the projection plot
set_plot_id <- function(prj_plot_id)({
    prj_plot_id(prj_plot_id()+1)
})

# Get projection plot name
get_prjs_plot_name <- function(dataset_name, encoder_name, selected, cluster, prj_plot_id, input){
<<<<<<< HEAD
    #log_print("Getting embedding plot name")
=======
>>>>>>> master
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
<<<<<<< HEAD
    log_print(paste0("embeddings plot name", plt_name))
=======
    print(paste0("embeddings plot name", plt_name))
>>>>>>> master
    plt_name
}

get_ts_plot_name <- function(dataset_name, encoder_name, prj_plot_id, input){
<<<<<<< HEAD
    log_print("Getting timeserie plot name")
    plt_name <- paste0(dataset_name,  "_", encoder_name, input$dr_method, "_ts.html")
    log_print(paste0("ts plot name: ", plt_name))
=======
    print("Getting timeserie plot name")
    plt_name <- paste0(dataset_name,  "_", encoder_name, input$dr_method, "_ts.html")
    print(paste0("ts plot name: ", plt_name))
>>>>>>> master
    plt_name
}