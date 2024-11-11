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
        indices <- unlist(seq(start_idx, end_idx))
        log_print(paste0("|| get_window_indices_ || idx ", idx, " sd ", start_idx, " ed ", end_idx), debug_group = 'tmi')
        window_indices <- c(window_indices, indices)
    }
    res <- unique(window_indices)
    do.call(log_print, c(list(mssg = paste0("|| get_window_indices_ || window_indices ~", res)), kwargs))
    res
}


 #compute_embeddings(
 #    tsdf,
 #    X,
 #    enc_l,
 #    enc_input_ready
 #){
 #
 #
 #}


apply_preprocessing_point_outlier <- function ( dataset, methods, wlen){
    if ("standard_scaler" %in% methods) {
        scaler <- sklearn$preprocessing$StandardScaler()
        dataset <- scaler$fit_transform(dataset)
    }
    if ("elliptic_envelope" %in% methods) {
        contamination <- 0.1 
        envelope <- sklearn$covariance$EllipticEnvelope(contamination = contamination)
        envelope_fit <- envelope$fit(dataset)
        dataset <- dataset[envelope$predict(dataset) == 1, ]
    }
    if ("median_filter" %in% methods) {
        kernel_size <- wlen  # window_len
        dataset <- scipy$signal$medfilt(dataset, kernel_size)
    }
    return (dataset)
}

apply_preprocessing_sequence_outlier <- function ( dataset, methods, wlen ){
    if ("dbscan" %in% methods) {
            eps <- 0.5  
            min_samples <- 5  
            dbscan <- sklearn$cluster$DBSCAN(eps = eps, min_samples = min_samples)
            labels <- dbscan$fit_predict(dataset)
            dataset <- dataset[labels != -1, ]
        }
        if ("isolation_forest" %in% methods) {
            contamination <- 0.1 
            isolation_forest <- sklearn$ensemble$IsolationForest(contamination = contamination)
            labels <- isolation_forest$fit_predict(dataset)
            dataset <- dataset[labels == 1, ]
        }
        if ("moving_average" %in% methods) {
            window_size <- wlen
            dataset <- np$convolve(dataset, np$ones(window_size) / window_size, mode = "valid")
        }

    return (dataset)

}

apply_preprocessing_segments <- function ( dataset, methods, wlen ) {
    if ("kmeans" %in% methods) {
        n_clusters <- 3 
        kmeans <- sklearn$cluster$KMeans(n_clusters = n_clusters)
        dataset <- kmeans$fit_predict(dataset) 
    }
    if ("moving_average" %in% methods) {
        window_size <- wlen 
        dataset <- np$convolve(dataset, np$ones(window_size) / window_size, mode = "valid")
    }
    return (dataset)
}

apply_preprocessing_trends <- function (dataset, methods, wlen ) {
    if ("pca" %in% methods) {
        n_components <- 1  
        pca <- sklearn$decomposition$PCA(n_components = n_components)
        dataset <- pca$fit_transform(dataset)
    }
    if ("exp_smoothing" %in% methods) {
        span <- 12  
        dataset <- statsmodels$tsa$holtwinters$ExponentialSmoothing(dataset, trend = "add")$fit()$fittedvalues
    }
    if ("linear_regression" %in% methods) {
        model <- sklearn$linear_model$LinearRegression()
        window_size <- wlen 
        dataset <- apply(sapply(1:(nrow(dataset) - window_size), function(i) {
            window <- dataset[i:(i + window_size - 1), ]
            model$fit(window, 1:window_size)$predict(window)
        }), 2, mean)
    }
    return (dataset)
}

apply_preprocessing <- function ( dataset, task_type, methods, wlen  ){
    if (not (is.null(methods) || length(methods) == 0)) {
        if (task_type == "point_outlier") {
            dataset <- apply_preprocessing_point_outlier(dataset, methods, wlen )
        } else if (task_type == "sequence_outlier") {
            dataset <-  apply_preprocessing_sequence_outlier ( dataset, methods, wlen )
        } else if (task_type == "segments") {
            dataset <- apply_preprocessing_sequence_outlier ( dataset, methods, wlen)
        } else if (task_type == "trends") {
            dataset <- apply_preprocessing_trends (dataset, methods, wlen )
        }   
    }
    return(dataset)
 }