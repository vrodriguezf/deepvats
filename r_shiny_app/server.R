#
# This is the server logic of a Shiny web application. You can run the
# application by clicking 'Run App' above.
#
# Find out more about building applications with Shiny here:
#
#    http://shiny.rstudio.com/
#
###########3 devtools::install_github("apache/arrow/r", ref = "tags/apache-arrow-14.0.0", subdir = "arrow/r")
shinyServer(function(input, output, session) {
    options(shiny.verbose = TRUE)
    #options(shiny.error = function() {
    #    traceback()
    #    stopApp()
    #})
  
    ######################
    #  REACTIVES VALUES  #
    ######################
    
    # Reactive values created to update the current range of the main slider input
    #slider_range <- reactiveValues(min_value = 1, max_value = 2)
    
    # Reactive value created to keep updated the selected precomputed clusters_labels artifact
    precomputed_clusters <- reactiveValues(selected = NULL)
    
    
    # Reactive value created to keep updated the selected clustering option
    clustering_options <- reactiveValues(selected = "no_clusters")
    
    
    # Reactive value created to configure the graph brush
    ranges <- reactiveValues(x = NULL, y = NULL)
    
    
    # Reactive value created to configure clusters options
    clusters_config <- reactiveValues(
        metric_hdbscan = DEFAULT_VALUES$metric_hdbscan,
        min_cluster_size_hdbscan = DEFAULT_VALUES$min_cluster_size_hdbscan,
        min_samples_hdbscan = DEFAULT_VALUES$min_samples_hdbscan,
        cluster_selection_epsilon_hdbscan = DEFAULT_VALUES$cluster_selection_epsilon_hdbscan
    )
    
    # Reactive values created to configure the appearance of the projections graph.
    config_style <- reactiveValues(
        path_line_size = DEFAULT_VALUES$path_line_size,
        path_alpha = DEFAULT_VALUES$path_alpha,
        point_alpha = DEFAULT_VALUES$point_alpha,
        point_size = DEFAULT_VALUES$point_size
    )
    
    # Reactive value created to store time series selected variables
    ts_variables <- reactiveValues(selected = NULL)
    
    
    
    #################################
    #  OBSERVERS & OBSERVERS EVENTS #
    #################################
    observeEvent(
        req(exists("encs_l")), 
        {
            freezeReactiveValue(input, "dataset")
            print("observeEvent encoders list enc_l | update dataset list | after freeze")
            updateSelectizeInput(
                session = session,
                inputId = "dataset",
                choices = encs_l %>% 
                map(~.$metadata$train_artifact) %>% 
                set_names()
            )
            on.exit(print("observeEvent encoders list encs_l | update dataset list -->"))
        }, 
        label = "input_dataset"
    )
    
    observeEvent(input$dataset, {
        #req(encs_l)
        print("--> observeEvent input_dataset | update encoder list")
        print(input$dataset)
        freezeReactiveValue(input, "encoder")
        print(paste0("observeEvent input_dataset | update encoders for dataset ", input$dataset))
        updateSelectizeInput(
            session = session,
            inputId = "encoder",
            choices = encs_l %>% 
            keep(~ .$metadata$train_artifact == input$dataset) %>% 
            #map(~ .$metadata$enc_artifact) %>% 
            names
        )
        ### TODO: Ver cómo poner bien esta ñapa para que no se actualizen los gráficos antes que el stride
        updateSliderInput(session, "stride", value = 0)
        ################
        on.exit(print("observeEvent input_dataset | update encoder list -->"))
    }, label = "input_encoder")
    
    # observeEvent(input$encoder, {
    #   freezeReactiveValue(input, "embs_ar")
    #   updateSelectizeInput(session = session, inputId = "embs_ar",
    #                        choices = embs_l %>%
    #                          keep(~ .$metadata$enc_artifact == input$encoder)
    #                        %>% names)
    # })
    
    observeEvent(
        input$encoder, 
        {
            #req(input$dataset, encs_l)
            #enc_ar = req(enc_ar())
            print("--> observeEvent input_encoder | update wlen")
            freezeReactiveValue(input, "wlen")
            print("observeEvent input_encoder | update wlen | Before enc_ar")
            enc_ar = enc_ar()
            print(paste0("observeEvent input_encoder | update wlen | enc_ar: ", enc_ar))
            print("observeEvent input_encoder | update wlen | Set wlen slider values")
            if (is.null(enc_ar$metadata$mvp_ws)) {
                print("observeEvent input_encoder | update wlen | Set wlen slider values from w | ")
                enc_ar$metadata$mvp_ws = c(enc_ar$metadata$w, enc_ar$metadata$w)
            }
            print(paste0("observeEvent input_encoder | update wlen | enc_ar$metadata$mvp_ws ", enc_ar$metadata$mvp_ws ))
            wmin <- enc_ar$metadata$mvp_ws[1]
            wmax <- enc_ar$metadata$mvp_ws[2]
            wlen <- enc_ar$metadata$w
            print(paste0("observeEvent input_encoder | update wlen | Update slider input (", wmin, ", ", wmax, " ) -> ", wlen ))
            updateSliderInput(session = session, inputId = "wlen",
                min = wmin,
                max = wmax,
                value = wlen
            )
            on.exit(print("observeEvent input_encoder | update wlen -->"))
        }
    )

    # Obtener el valor de stride
    enc_ar_stride = reactive({
        print("--> reactive enc_ar_stride")
        stride <- enc_ar()$metadata$stride
        on.exit(print(paste0("reactive_enc_ar_stride | --> ", stride)))
        stride
    })
        
    observeEvent(input$wlen, {
        req(input$wlen != 0)
        print(paste0("--> observeEvent input_wlen | update slide stride value | wlen ",  input$wlen))
        tryCatch({
            old_value = input$stride
            if (input$stride == 0){
                old_value = enc_ar_stride()
            }
            freezeReactiveValue(input, "stride")
            print(paste0("oserveEvent input_wlen | update slide stride value | Update stride to ", old_value))
            updateSliderInput(
                session = session, inputId = "stride", 
                min = 1, max = input$wlen, 
                value = ifelse(old_value <= input$wlen, old_value, 1)
            )
            }, 
            error = function(e){
                print(paste0("observeEvent input_wlen | update slide stride value | Error | ", e$message))
            }, 
            warning = function(w) {
                message(paste0("observeEvent input_wlen | update slide stride value | Warning | ", w$message))
            }
        )
        on.exit(print(paste0( 
            "observeEvent input_wlen | update slide stride value | Finally |  wlen min ",  
            1, " max ", input$wlen, " current value ", input$stride, " -->")))
    })

    # Update "metric_hdbscan" selectInput when the app is loaded
    observe({
        print("--> observe metric_hdbscan | update metric_hdbscan choices")
        updateSelectInput(
            session = session,
            inputId = "metric_hdbscan",
            choices = names(req(hdbscan_metrics))
        )
        on.exit(print("observe metric_hdbscan | update metric_hdbscan choices-->"))
    })
    # Update the range of point selection when there is new data
    # observeEvent(X(), {
    #   #max_ = ts_ar()$metadata$TS$n_samples
    #   max_ = dim(X())[[1]]
    #   freezeReactiveValue(input, "points_emb")
    #   updateSliderInput(session = session, inputId = "points_emb",
    #                     min = 1, max = max_, value = c(1, max_))
    # })

    # Update selected time series variables and update interface config
    observeEvent(tsdf(), {
        print("--> observeEvent tsdf | update select variables")
        freezeReactiveValue(input, "select_variables")
        ts_variables$selected <- names(tsdf())
        updateCheckboxGroupInput(
            session = session,
            inputId = "select_variables",
            choices = ts_variables$selected,
            selected = ts_variables$selected
        )



        on.exit(print("--> observeEvent tsdf | update select variables -->"))
    }, label = "select_variables")
    
    # Update slider_range reactive values with current samples range
    # observe({
    #     req(input$points_emb)
    #     slider_range$min_value <- input$points_emb[1]
    #     slider_range$max_value <- input$points_emb[2]
    # })
    
    # Update precomputed_clusters reactive value when the input changes
    observeEvent(input$clusters_labels_name, {
        print("--> observe | precomputed_cluster selected ")
        precomputed_clusters$selected <- req(input$clusters_labels_name)
        print(paste0("observe | precomputed_cluster selected --> | ", precomputed_cluster$selected))
    })
    
    
    # Update clustering_options reactive value when the input changes
    observe({
        print("--> Observe clustering options")
        clustering_options$selected <- req(input$clustering_options)
        print("Observe clustering options -->")
    })

    
    # Update clusters_config reactive values when user clicks on "calculate_clusters" button
    observeEvent(input$calculate_clusters, {
        print("--> observe event calculate_clusters | update clusters_config")
        clusters_config$metric_hdbscan <- req(input$metric_hdbscan)
        clusters_config$min_cluster_size_hdbscan <- req(input$min_cluster_size_hdbscan)
        clusters_config$min_samples_hdbscan <- req(input$min_samples_hdbscan)
        clusters_config$cluster_selection_epsilon_hdbscan <- req(input$cluster_selection_epsilon_hdbscan)
        #on.exit(print("observe event calculate_clusters | update clusters_config -->"))
    })
    
    
    # Observe the events related to zoom the projections graph
    observeEvent(input$zoom_btn, {
        
        print("--> observeEvent zoom_btn")
        brush <- input$projections_brush
        if (!is.null(brush)) {
            if(isTRUE(input$zoom_btn)){
                ranges$x <- c(brush$xmin, brush$xmax)
                ranges$y <- c(brush$ymin, brush$ymax)
            }else {
                ranges$x <- NULL
                ranges$y <- NULL
            }
            
        } else {
            ranges$x <- NULL
            ranges$y <- NULL
        }
        on.exit(print("observeEvent zoom_btn -->"))
    })
    
    
    # Observe the events related to change the appearance of the projections graph
    observeEvent(input$update_prj_graph,{
        style_values <- list(path_line_size = input$path_line_size ,
                             path_alpha = input$path_alpha,
                             point_alpha = input$point_alpha,
                             point_size = input$point_size)
        
        if (!is.null(style_values)) {
            config_style$path_line_size <- style_values$path_line_size
            config_style$path_alpha <- style_values$path_alpha
            config_style$point_alpha <- style_values$point_alpha
            config_style$point_size <- style_values$point_size
        } else {
            config_style$path_line_size <- NULL
            config_style$path_alpha <- NULL
            config_style$point_alpha <- NULL
            config_style$point_size <- NULL
        }
    })
    
    
    # Update ts_variables reactive value when time series variable selection changes
    observeEvent(input$select_variables, {
        ts_variables$selected <- input$select_variables
    })
    
    
    # Observe to check/uncheck all variables
    observeEvent(input$selectall,{
        req(tsdf)
        ts_variables$selected <- names(tsdf())
        #ts_variables$selected <- names(req(tsdf()))
        if(input$selectall %%2 == 0){
            updateCheckboxGroupInput(session = session, 
                                     inputId = "select_variables",
                                     choices = ts_variables$selected, 
                                     selected = ts_variables$selected)
        } else {
            updateCheckboxGroupInput(session = session, 
                                     inputId = "select_variables",
                                     choices = ts_variables$selected, 
                                     selected = NULL)
        }
    })
    
    
    
    ###############
    #  REACTIVES  #
    ###############
    wlen_debounced <- reactive(input$wlen) %>% debounce(500)

    X <- reactive({
        req(wlen_debounced() != 0, input$stride != 0, tsdf())
        print("--> Reactive X | Update Sliding Window")
        print(paste0("reactive X | wlen ", wlen_debounced(), " | stride ", input$stride, " | Let's prepare data"))
        
        t_init <- Sys.time()
        enc_input <- tsai_data$prepare_forecasting_data(
            tsdf(),
            fcst_history = wlen_debounced()
        )[[1]]
        t_fin <- Sys.time()
        t_sliding_window_view = t_fin - t_init
        print(paste0("SWV: ", t_sliding_window_view, " secs "))
            #value   = c(as.integer(1), as.integer(max(10000,length(enc_input)))))
        

        on.exit(print(paste0("reactive X | Update sliding window | Apply stride | enc_input ~ ", dim(enc_input))))
        enc_input
    })
    
    # Time series artifact
    ts_ar <- eventReactive(
        input$dataset, 
        {
        req(input$dataset)
        print(paste0("--> eventReactive ts_ar | Update dataset artifact | hash ", input$dataset, "-->"))
        ar <- api$artifact(input$dataset, type='dataset')
        on.exit(print("eventReactive ts_ar -->"))
        ar
    }, label = "ts_ar")

    #ts_ar <- eventReactive(input$dataset, {
    #    req(input$dataset)
    #    print(paste0("--> eventReactive ts_ar | Update dataset artifact  | stride ", input$stride, "| hash ", input$dataset, "-->"))
    #    dataset <- api$artifact(input$dataset, type='dataset')
    #    if(anyDuplicated(rownames(dataset))) {
    #        print("eventReactive ts_ar | Update dataset artifact | delete duplicated rows")
    #        dataset <- dataset[!duplicated(rownames(dataset)), ]
    #    }
    #    dataset
    #}, label = "ts_ar")
    
    # Get timeseries artifact metadata
    ts_ar_config = reactive({
        print("--> reactive ts_ar_config | List used artifacts")
        ts_ar <- req(ts_ar())
        print(paste0("reactive ts_ar_config | List used artifacts | hash", ts_ar$hash))
        list_used_arts = ts_ar$metadata$TS
        list_used_arts$vars = ts_ar$metadata$TS$vars %>% stringr::str_c(collapse = "; ")
        list_used_arts$name = ts_ar$name
        list_used_arts$aliases = ts_ar$aliases
        list_used_arts$artifact_name = ts_ar$name
        list_used_arts$id = ts_ar$id
        list_used_arts$created_at = ts_ar$created_at
        list_used_arts
        on.exit(print("reactive ts_ar_config -->"))
    })
    
    # selected_embs_ar = eventReactive(input$embs_ar, {
    #   embs_l[[input$embs_ar]]
    # })
    
    # embeddings object. Get it from local if it is there, otherwise download
    # embs = reactive({
    #   selected_embs_ar = req(selected_embs_ar())
    #   print("embs")
    #   fname = file.path(DEFAULT_PATH_WANDB_ARTIFACTS, 
    #                     selected_embs_ar$metadata$ref$hash)
    #   if (file.exists(fname))
    #     py_load_object(filename = fname)
    #   else
    #     selected_embs_ar$to_obj()
    # })
    
    # Get encoder artifact
    enc_ar <- eventReactive(
        input$encoder, 
        {
            print(paste0("eventReactive enc_ar | Enc. Artifact: ", input$encoder))
            result <- tryCatch({
                api$artifact(input$encoder, type = 'learner')
            }, error = function(e){
                print(paste0("eventReactive enc_ar | Error: ", e$message))
                NULL
            })
            on.exit(print("envent reactive enc_ar -->"))
            result
        }, 
        ignoreInit = T
    )
   
   # Encoder
    enc <- eventReactive(
        enc_ar(), 
    {
        req(input$dataset, input$encoder)
        print("--> eventReactive enc | load encoder ")
        encoder_artifact <- enc_ar()
        enc <- py_load_object(
            file.path(
                DEFAULT_PATH_WANDB_ARTIFACTS, 
                encoder_artifact$metadata$ref$hash
            )
        )
        on.exit(print("eventReactive enc | load encoder -->"))
        enc
    })

    
    
    embs <- reactive({
        req(X(), enc_l <- enc())
        print("--> reactive embs | get embeddings")
        if (torch$cuda$is_available()){
            print(paste0("CUDA devices: ", torch$cuda$device_count()))
          } else {
            print("CUDA NOT AVAILABLE")
        }
        t_init <- Sys.time()
        print(
            paste0(
                "reactive embs | get embeddings | Just about to get embedings. Device number: ", 
                torch$cuda$current_device() 
            )
        )
        
        print("reactive embs | get embeddings | Get batch size and dataset")

        dataset_logged_by <- enc_ar()$logged_by()
        bs = dataset_logged_by$config$batch_size
        stride = input$stride 
        
        print(paste0("reactive embs | get embeddings (set stride set batch size) | Stride ", input$stride, " | batch size: ", bs ))
        enc_input = X()
        chunk_max = 10000000
        shape <- dim(enc_input)
        print(paste0("reactive embs | get embeddings (set stride set batch size) | enc_input shape: ", shape ))
        chunk_size_ = min(shape[1]*shape[2],chunk_max/(shape[1]*shape[2]))
        N = max(3200,floor(chunk_size_/32))
        chunk_size = N*32
        print(paste0("reactive embs | get embeddings (set stride set batch size) | Chunk_size ", chunk_size, " | shape[1]*shape[2]: ", shape[1]*shape[2] ))
        result <- dvats$get_enc_embs_set_stride_set_batch_size(
            X = enc_input, 
            enc_learn = enc_l, 
            stride = input$stride, 
            batch_size = bs, 
            cpu = FALSE, 
            print_flag = FALSE, 
            time_flag = TRUE, 
            chunk_size = chunk_size,
            check_memory_usage = TRUE
        )
        t_end <- Sys.time()
        diff <- t_end - t_init
        diff_secs <- as.numeric(diff, units = "secs")
        diff_mins <- as.numeric(diff, units = "mins")
        print(paste0("get_enc_embs total time: ", diff_secs, " secs thus ", diff_mins, " mins"))
        X <- NULL
        gc(verbose=TRUE)
        on.exit(print("reactive embs | get embeddings -->"))
        result
    })
#enc = py_load_object(
#    os.path.join(
#        DEFAULT_PATH_WANDB_ARTIFACTS, 
#        hash
#    )
#)
#embs_py_code <- "
#import os
#from dvats.all import get_enc_embs
#from torch import cuda
#from time import time
#import pickle
#
#path = os.path.join(wandb_path, hash)
#print(path)
#with open(path, 'rb') as f:
#    enc = pickle.load(f)
#print('reactive embs | load encoder | Set batchsize')
#enc.bs = batch_size
#print('reactive embs | load encoder | Batchsize: ', enc.bs)
#print('--> reactive embs | get embeddings | enc.bs ', enc.bs )
#if cuda.is_available():
#    print('CUDA devices: ', cuda.device_count())
#else:
#    print('CUDA NOT AVAILABLE')
#t_init = time()
#print(
#    '--> reactive embs | get embeddings | Just about to get embedings. Device number: ', 
#    cuda.current_device(), 
#    ' Batch size: ', enc.bs
#)
#result = get_enc_embs(X = enc_input, enc_learn = enc, cpu = False)
#t_end = time()
#diff = t_end - t_init
#diff_secs = diff
#diff_mins = diff / 60
#"   

#embs = reactive({
#    req(input$dataset, X())
#    print("--> reactive embs | get embeddings -->")
#    enc_ar <- req(enc_ar())
#    dataset_logged_by = enc_ar$logged_by()
#    batch_size = dataset_logged_by$config$batch_size
#    hash <- enc_ar$metadata$ref$hash
#    print(paste0("reactive embs | get embeddings | hash ", hash, " | logged_by_batch_size ", batch_size))
#    py$wandb_path <- DEFAULT_PATH_WANDB_ARTIFACTS
#    print(paste0("reactive embs | get embeddings | path ", py$wandb_path))
#    py$hash <- hash
#    print(paste0("reactive embs | get embeddings | hash ", py$hash))
#    py$enc_input <- X()
#    py$dataset_logged_by <- dataset_logged_by
#    py$batch_size <- batch_size
#    print(paste0("reactive embs | get embeddings | bs ", py$batch_size))
#    print(reticulate::py_config())
#    print(paste0("reactive embs | get embeddings | Enter embs_py code! ", embs_py_code))
#    py_run_string(embs_py_code)
#    print(paste0("reactive embs | get embeddings | Outside embs_py codee! ", embs_py_code))
#    diff_secs <- py$diff_secs
#    diff_mins <- py$diff_mins
#    result <- py$result
#    print(paste0("get_enc_embs total time", diff_secs, " secs thus ", diff_mins, " mins"))
#    result
#})

 prj_object_cpu <- reactive({
        embs = req(embs(), input$dr_method)
        embs = embs[complete.cases(embs),]
        print("--> prj_object")
        #print(embs) #--
        #print(paste0("--> prj_object | UMAP params ", str(umap_params_)))
        print("--> prj_object | UMAP params ")
        
        res = switch( input$dr_method,
            #### Comprobando parametros para saber por qué salen diferentes los embeddings
            ######### Comprobando los parámetros
            #UMAP = dvats$get_UMAP_prjs(input_data = embs, cpu=F, n_neighbors = 15, min_dist = 0.1, random_state=as.integer(1234)),
            UMAP = dvats$get_UMAP_prjs(
                input_data  = embs, 
                cpu         = TRUE, 
                print_flag  = TRUE,
                n_neighbors = input$prj_n_neighbors, 
                min_dist    = input$prj_min_dist, 
                random_state= as.integer(input$prj_random_state)
            ),
            TSNE = dvats$get_TSNE_prjs(
                X = embs, 
                cpu = TRUE, 
                random_state=as.integer(input$prj_random_state)
            ),
            PCA = dvats$get_PCA_prjs(
                X = embs, 
                cpu = TRUE, 
                random_state=as.integer(input$prj_random_state)
            )
        )
      res = res %>% as.data.frame # TODO: This should be a matrix for improved efficiency
      colnames(res) = c("xcoord", "ycoord")
      on.exit(print(" prj_object -->"))
      flush.console()
      Sys.sleep(5)
      #browser()
      res
    })

    prj_object <- reactive({
        print("--> prj_object")
        embs = req(embs(), input$dr_method)
        print("prj_object | Before complete cases ")
        embs = embs[complete.cases(embs),]
        #print(embs) #--
        #print(paste0("--> prj_object | UMAP params ", str(umap_params_)))
        print("prj_object | Before switch ")
        
        cpu_flag = ifelse(input$cpu_flag == "CPU", TRUE, FALSE)

        res = switch( input$dr_method,
            #### Comprobando parametros para saber por qué salen diferentes los embeddings
            ######### Comprobando los parámetros
            #UMAP = dvats$get_UMAP_prjs(input_data = embs, cpu=F, n_neighbors = 15, min_dist = 0.1, random_state=as.integer(1234)),
            UMAP = dvats$get_UMAP_prjs(
                input_data  = embs, 
                cpu         = cpu_flag, 
                print_flag  = TRUE,
                n_neighbors = input$prj_n_neighbors, 
                min_dist    = input$prj_min_dist, 
                random_state= as.integer(input$prj_random_state)
            ),
            TSNE = dvats$get_TSNE_prjs(
                X = embs, 
                cpu=FALSE, 
                random_state=as.integer(input$prj_random_state)
            ),
            PCA = dvats$get_PCA_prjs(
                X = embs, 
                cpu=FALSE, 
                random_state=as.integer(input$prj_random_state)
            )
        )
      res = res %>% as.data.frame # TODO: This should be a matrix for improved efficiency
      colnames(res) = c("xcoord", "ycoord")
      on.exit(print(" prj_object -->"))
      flush.console()
      Sys.sleep(5)
      #browser()
      res
    })
    
    # Load and filter TimeSeries object from wandb
    tsdf <- reactive(
        {
            
            req(
                input$wlen > 0, 
                input$stride > 0, 
                input$dataset, 
                input$encoder
            )
            #req(input$dataset, input$encoder, input$stride != 0)
            ts_ar <- req(ts_ar())
            print("--> Reactive tsdf | Before req 2 - get ts_ar")
            print(paste0("Reactive tsdf | ts artifact ", ts_ar))
            # Take the first and last element of the timeseries corresponding to the subset of the embedding selectedx
            # first_data_index <- get_window_indices(idxs = input$points_emb[[1]], w = input$wlen, s = input$stride)[[1]] %>% head(1)
            # last_data_index <- get_window_indices(idxs = input$points_emb[[2]], w = input$wlen, s = input$stride)[[1]] %>% tail(1)
            
            t_init <- Sys.time()
            ts_ar_hash=ts_ar$metadata$TS$hash
            path = file.path(DEFAULT_PATH_WANDB_ARTIFACTS, ts_ar_hash)
            tsdf_ <-  tryCatch({
                print(paste0("Reactive tsdf | read_feather ", path ))
                read_feather(path, as_data_frame = TRUE, mmap = TRUE) %>% 
                rename('timeindex' = `__index_level_0__`) %>% 
                column_to_rownames(var = "timeindex")
            }, error = function(e){
                print(paste0("Reactive tsdf | Error while loading TimeSeries object. Error:", e$message))
                print("Reactive tsdf | Retry TimeSeries load")
                tryCatch({
                    read_feather(file.path(DEFAULT_PATH_WANDB_ARTIFACTS, filename)) %>%
                    rownames_to_column("timeindex") %>% 
                    # slice(first_data_index:last_data_index) %>%
                    column_to_rownames(var = "timeindex")
                }, error = function(e){
                    print(paste0("Reactive tsdf |2| Error while loading TimeSeries object. Exit. Error:", e$message))
                    stop()
                    data.frame()
                }, 
                warning = function(w){
                print(paste0("Reactive tsdf |2| Warning ", w))
                data.frame()
                }
            )}, warning = function(w){
                print(paste0("Reactive tsdf | Warning ", w))
                data.frame()
            } )

            t_fin  <- Sys.time()
            print(paste0("Reactive tsdf | Execution time: ", t_fin - t_init, " seconds"))
            on.exit(print("Reactive tsdf | Object loaded --> "))
            tsdf_
        })
    
    # Auxiliary object for the interaction ts->projections
    tsidxs_per_embedding_idx <- reactive({
      req(input$wlen != 0, input$stride != 0)
      get_window_indices(1:nrow(req(projections())), w = input$wlen, s = input$stride)
    })
    
    # Filter the embedding points and calculate/show the clusters if conditions are met.
    projections <- reactive({
        print("--> Projections")
        req(prj_object(), input$dr_method)
        #prjs <- req(prj_object()) %>% slice(input$points_emb[[1]]:input$points_emb[[2]])
        print("Projections | before prjs")
        prjs <- prj_object()
        req(input$dataset, input$encoder, input$wlen, input$stride)
        print("Projections | before switch")
        switch(clustering_options$selected,
            precomputed_clusters = {
               filename <- req(selected_clusters_labels_ar())$metadata$ref$hash
               clusters_labels <- py_load_object(filename = file.path(DEFAULT_PATH_WANDB_ARTIFACTS, filename))
               #prjs$cluster <- clusters_labels[input$points_emb[[1]]:input$points_emb[[2]]]
               prjs$cluster <- clusters_labels
            },
            calculate_clusters = {
                clusters = hdbscan$HDBSCAN(
                    min_cluster_size = as.integer(clusters_config$min_cluster_size_hdbscan),
                    min_samples = as.integer(clusters_config$min_samples_hdbscan),
                    cluster_selection_epsilon = clusters_config$cluster_selection_epsilon_hdbscan,
                    metric = clusters_config$metric_hdbscan
                )$fit(prjs)
                score = dvats$cluster_score(prjs, clusters$labels_, TRUE)
                print(paste0("Projections | Score ", score))
                if (score <= 0) {
                    print(paste0("Projections | Repeat projections with CPU because of low quality clusters | score ", score))
                    prjs <- prj_object_cpu()
                    clusters = hdbscan$HDBSCAN(
                        min_cluster_size = as.integer(clusters_config$min_cluster_size_hdbscan),
                        min_samples = as.integer(clusters_config$min_samples_hdbscan),
                        cluster_selection_epsilon = clusters_config$cluster_selection_epsilon_hdbscan,
                        metric = clusters_config$metric_hdbscan
                    )$fit(prjs)
                    score = dvats$cluster_score(prjs, clusters$labels_, TRUE)
                    print(paste0("Projections | Repeat projections with CPU because of low quality clusters | score ", score))
                }
                prjs$cluster <- clusters$labels_


             })
        
        on.exit(print("Projections -->"))
      prjs
    })
    
    # Update the colour palette for the clusters
    update_palette <- reactive({
        prjs <- req(projections())
        if ("cluster" %in% names(prjs)) {
            unique_labels <- unique(prjs$cluster)
            print(unique_labels)
            ## IF the value "-1" exists, assign the first element of mycolors to #000000, if not, assign the normal colorRampPalette
            if (as.integer(-1) %in% unique_labels) 
                colour_palette <- append("#000000", colorRampPalette(brewer.pal(12,"Paired"))(length(unique_labels)-1))
            else 
                colour_palette <- colorRampPalette(brewer.pal(12,"Paired"))(length(unique_labels))
        }
        else
            colour_palette <- "red"
        
        colour_palette
    })
    

    
    ts_plot_base <- reactive({
        print("--> ts_plot_base")
        on.exit(print("ts_plot_base -->"))

        start_date = rownames(tsdf())[1]
        end_date = rownames(tsdf())[1000000]
        end_date = min(end_date, nrow(tsdf()))
        print(tsdf()[1])
        print(paste0("ts_plot_base | start_date: ", start_date, " end_date: ", end_date))

        ts_plt = dygraph(
            tsdf() %>% select(ts_variables$selected),
            width="100%", height = "400px"
        ) %>% 
        dyRangeSelector(c(start_date, end_date)) %>% 
        dyHighlight(hideOnMouseOut = TRUE) %>%
        dyOptions(labelsUTC = FALSE  ) %>%
        dyCrosshair(direction = "vertical")%>%
        dyLegend(show = "follow", hideOnMouseOut = TRUE) %>%
        dyUnzoom() %>%
        dyHighlight(highlightSeriesOpts = list(strokeWidth = 3)) %>%
        dyCSS(
            textConnection(
                ".dygraph-legend > span { display: none; }
                .dygraph-legend > span.highlight { display: inline; }"
            )
        )
    })

    
    

    # Generate timeseries data for dygraph dygraph
    ts_plot <- reactive({
        print("--> ts_plot | Before req 1")
        on.exit(print("ts_plot -->"))

        req(tsdf(), ts_variables, input$wlen != 0, input$stride)

        ts_plt = ts_plot_base()   

        print("ts_plot | bp")
        #miliseconds <-  ifelse(nrow(tsdf()) > 1000000, 2000, 1000)
        bp = brushedPoints(prj_object(), input$projections_brush, allRows = TRUE) #%>% debounce(miliseconds) #Wait 1 seconds: 1000
        #if (!is.data.frame(bp)) {bp = bp_}

        print("ts_plot | embedings idxs ")
        embedding_idxs <- bp %>% rownames_to_column("index") %>% dplyr::filter(selected_ == TRUE) %>% pull(index) %>% as.integer
        # Calculate windows if conditions are met (if embedding_idxs is !=0, that means at least 1 point is selected)
        print("ts_plot | Before if")
        if ((length(embedding_idxs)!=0) & isTRUE(input$plot_windows)) {
            # Get the window indices
            window_indices <- get_window_indices(embedding_idxs, input$wlen, input$stride)
            # Put all the indices in one list and remove duplicates
            unlist_window_indices <- unique(unlist(window_indices))
            # Calculate a vector of differences to detect idx where a new window should be created 
            diff_vector <- diff(unlist_window_indices,1)
            # Take indexes where the difference is greater than one (that represent a change of window)
            idx_window_limits <- which(diff_vector!=1)
            # Include the first and last index to have a whole set of indexes.
            idx_window_limits <- c(1, idx_window_limits, length(unlist_window_indices))
            # Create a reduced window list
            reduced_window_list <-  vector(mode = "list", length = length(idx_window_limits)-1)
            # Populate the first element of the list with the idx of the first window.
            reduced_window_list[[1]] <- c(unlist_window_indices[idx_window_limits[1]],
                                unlist_window_indices[idx_window_limits[1+1]])
            # Populate the rest of the list
            for (i in 2:(length(idx_window_limits)-1)){
                reduced_window_list[[i]]<- c(unlist_window_indices[idx_window_limits[i]+1],
                                   unlist_window_indices[idx_window_limits[i+1]])
            }
            # # Plot the windows
            for(ts_idxs in reduced_window_list) {
                ts_plt <- ts_plt %>% dyShading(
                    from = rownames(tsdf())[head(ts_idxs, 1)],
                    to = rownames(tsdf())[tail(ts_idxs, 1)],
                    color = "#CCEBD6"
                )
            }
            
            # NOTE: This code block allows you to plot shadyng at once. 
            #       The traditional method has to plot the dygraph n times 
            #       (n being the number of rectangles to plot). With the adjacent
            #       code it is possible to plot the dygraph only once. Currently
            #       it does not work well because there are inconsistencies in the
            #       timezones of the time series and shiny (there is a two-hour shift[the current plot method works well]),
            #       which does not allow this method to be used correctly. If that
            #       were fixed in the future everything would work fine.
            # num_rects <- length(reduced_window_list)
            # rects_ini <- vector(mode = "list", length = num_rects)
            # rects_fin <- vector(mode = "list", length = num_rects)
            # for(i in 1:num_rects) {
            #     rects_ini[[i]] <- head(reduced_window_list[[i]],1)
            #     rects_fin[[i]] <- tail(reduced_window_list[[i]],1)
            # }
            # ts_plt <- vec_dyShading(ts_plt,rects_ini, rects_fin,"red", rownames(tsdf()))
        }
        
        ts_plt
    })
    
    
    
    #############
    #  OUTPUTS  #
    #############
    
    # Generate encoder info table
    #output$enc_info = renderDataTable({
    #  print("enc_info")
      #map(~ .$value) %>%
    #  encoder_artiffact <- req(enc_ar())
    #  print(paste0("Encoder artiffact", encoder_artiffact))
      #req(enc_ar())$metadata %>%
    #  print("Encoder artiffact metadata")
    #  print(encoder_artiffact$metadata)
    #  encoder_artiffact$metadata %>%
    #    enframe()
    #})
    output$enc_info = renderDataTable({
        selected_encoder_name <- req(input$encoder)
        print(paste0("--> Encoder artiffact", selected_encoder_name))
        selected_encoder <- encs_l[[selected_encoder_name]]
        encoder_metadata <- req(selected_encoder$metadata)
        print(paste0("Encoder artiffact | encoder metadata ", selected_encoder_name))
        encoder_metadata %>%
        enframe()
        on.exit("Encoder artiffact -->")
    })
    
    # Generate time series info table
    output$ts_ar_info = renderDataTable({
        ts_ar_config() %>% 
            enframe()
    })



    
       
    # Generate projections plot
    output$projections_plot <- renderPlot({
        print("--> projections_plot before req 1")
        #req(input$dataset, input$encoder, input$wlen, input$stride)
        print("projections_plot before req 2")
        prjs_ <- req(projections())
        print("projections_plot | Prepare column highlights")
        # Prepare the column highlight to color data
        if (!is.null(input$ts_plot_dygraph_click)) {
            selected_ts_idx = which(ts_plot()$x$data[[1]] == input$ts_plot_dygraph_click$x_closest_point)
            projections_idxs = tsidxs_per_embedding_idx() %>% map_lgl(~ selected_ts_idx %in% .)
            prjs_$highlight = projections_idxs
        } else {
            prjs_$highlight = FALSE
        }
        # Prepare the column highlight to color data. If input$generate_cluster has not been clicked
        # the column cluster will not exist in the dataframe, so we create with the value FALSE
        if(!("cluster" %in% names(prjs_)))
            prjs_$cluster = FALSE
        print("projections_plot | GoGo Plot!")
        plt <- ggplot(data = prjs_) + 
            aes(x = xcoord, y = ycoord, fill = highlight, color = as.factor(cluster)) + 
            scale_colour_manual(name = "clusters", values = req(update_palette())) +
            geom_point(shape = 21,alpha = config_style$point_alpha, size = config_style$point_size) + 
            scale_shape(solid = FALSE) +
            #geom_path(size=config_style$path_line_size, colour = "#2F3B65",alpha = config_style$path_alpha) + 
            guides() + 
            scale_fill_manual(values = c("TRUE" = "green", "FALSE" = "NA"))+
            coord_cartesian(xlim = ranges$x, ylim = ranges$y, expand = TRUE)+
            theme_void() + 
            theme(legend.position = "none")
        
        if (input$show_lines){
            #plt <- plt + geom_path(size=config_style$path_line_size, colour = "#2F3B65",alpha = config_style$path_alpha)
            plt <- plt + geom_path(linewidth=config_style$path_line_size, colour = "#2F3B65",alpha = config_style$path_alpha)
        }

        observeEvent(input$savePlot, {
            plt <- plt + theme(plot.background = element_rect(fill = "white"))
            ggsave(filename = prjs_plot_name(), plot = plt, path = "../data/plots/")
        })
        #observeEvent(c(input$dataset, input$encoder, clustering_options$selected), {   
            #req(input$dataset, input$encoder)
            #print("!-- CUDA?: ", torch$cuda$is_available())
            #prjs_ <- req(projections())
            #filename <- prjs_plot_name()
            #print(paste("saving embedding plot to ",filename))
            #ggsave(filename = filename, plot = plt, path="../data/plots/") 
            #print("Embeding plot saved")
        #})
        
        plt
    })
    
    
    # Render projections plot
    output$projections_plot_ui <- renderUI(
        {
            print("--> output projections_plot_UI")
            ppui <- plotOutput(
                "projections_plot", 
                click = "projections_click",
                brush = "projections_brush",
                height = input$embedding_plot_height
            ) %>% withSpinner()
            on.exit(print("output projections_plot_UI -->"))      
            ppui
        }
    )
    
    
    # Render information about the selected point in the time series graph
    output$point <- renderText({
        req(input$ts_plot_dygraph_click$x_closest_point)
        ts_idx = which(ts_plot()$ts$x$data[[1]] == input$ts_plot_dygraph_click$x_closest_point)
        paste0('X = ', strftime(req(input$ts_plot_dygraph_click$x_closest_point), "%F %H:%M:%S"), 
               '; Y = ', req(input$ts_plot_dygraph_click$y_closest_point),
               '; X (raw) = ', req(input$ts_plot_dygraph_click$x_closest_point))
    })

    
    # Render information about the selected point and brush in the projections graph
    output$projections_plot_interaction_info <- renderText({
        xy_str <- function(e) {
            if(is.null(e)) return("NULL\n")
            paste0("x=", round(e$x, 1), " y=", round(e$y, 1), "\n")
        }
        xy_range_str <- function(e) {
            if(is.null(e)) return("NULL\n")
            paste0("xmin=", round(e$xmin, 1), " xmax=", round(e$xmax, 1), 
                   " ymin=", round(e$ymin, 1), " ymax=", round(e$ymax, 1))
        }
        paste0(
            "click: ", xy_str(input$projections_click),
            "brush: ", xy_range_str(input$projections_brush)
        )
    })
    
    
    
    # Generate time series plot
    output$ts_plot_dygraph <- renderDygraph(
        {
            req (
                input$dataset, 
                input$encoder,
                input$wlen != 0, 
                input$stride != 0
            )
            #print("Saving time series plot")
            ts_plot <- req(ts_plot())
            #save_path <- file.path("..", "data", "plots", ts_plot_name())
            #htmlwidgets::saveWidget(ts_plot, file = save_path, selfcontained=TRUE)
            #print(paste0("Time series plot saved to", save_path))
            ts_plot
            #req(ts_plot())
        }   
    )


    ########### Saving graphs in local
    get_prjs_plot_name <- function(dataset_name, encoder_name, selected, cluster){
        #print("Getting embedding plot name")
        plt_name <- paste0(dataset_name,"_", encoder_name, "_", input$dr_method)
        if (!is.null(selected) && selected == "precomputed_clusters") {
            plt_name <- paste0(plt_name, "_cluster_", cluster, "_prjs.png")
        } else {
            plt_name <- paste0(plt_name, "_prjs.png")
        }
        print(paste0("embeddings plot name", plt_name))
        plt_name
    }

    get_ts_plot_name <- function(dataset_name, encoder_name){
        print("Getting timeserie plot name")
        plt_name <- paste0(dataset_name,  "_", encoder_name, input$dr_method, "_ts.html")
        print(paste0("ts plot name: ", plt_name))
        plt_name
    }

    prjs_plot_name <- reactive({
        dataset_name <- basename(input$dataset)
        encoder_name <- basename(input$encoder)
        get_prjs_plot_name(dataset_name, encoder_name, clustering_options$selected, prjs_$cluster)
    })
    
    ts_plot_name <- reactive({
        dataset_name <- basename(input$dataset)
        encoder_name <- basename(input$encoder)
        get_ts_plot_name(dataset_name, encoder_name)
    })
    
})

