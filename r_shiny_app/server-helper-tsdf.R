# Function for parallel timeindex conversion
parallel_posfix <- function(df) {
    chunk_size = 100000
    num_chunks = ceiling(nrow(df)/chunk_size)
    chunks=split(df$timeindex, ceiling(seq_along(df$timeindex)/chunk_size))
            
    log_print(paste0("Parallel posfix | Chunks: ", num_chunks))
    cl = parallel::makeCluster(4)
    parallel::clusterEvalQ(cl, library(fasttime))
            
    log_print(paste0("Parallel posfix | Cluster ", cl, " of ", detectCores()))
    flush.console()
    
    result <- parallel::clusterApply(cl, chunks, function(chunk) {
        cat("Processing chunk\n")
        flush.console()
        #fasttime::fastPOSIXct(chunk, format = "%Y-%m-%d %H:%M:%S")
        as.POSIXct(chunk)
    })
    stopCluster(cl)
    log_print(" Reactive tsdf | Make conversion -->")
    log_print(" Reactive tsdf | Make conversion ")
    flush.console()
    return(unlist(result))
}