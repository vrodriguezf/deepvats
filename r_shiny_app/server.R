#
# This is the server logic of a Shiny web application. You can run the
# application by clicking 'Run App' above.
#
# Find out more about building applications with Shiny here:
#
#    http://shiny.rstudio.com/
#
###########3 devtools::install_github("apache/arrow/r", ref = "tags/apache-arrow-14.0.0", subdir = "arrow/r")


source("./server-helper.R")

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
  
  # Reactive value created to store the encoder_input
  X <- reactiveVal()
  
  # Reactive value created to store encoder artifact stride
  enc_ar_stride <- eventReactive(enc_ar(), {
    stride = ceiling(enc_ar()$metadata$stride/2)
  })
  
  # Time series artifact
  ts_ar <- eventReactive(
    input$dataset, 
    {
      req(input$dataset)
      ar <- api$artifact(input$dataset, type='dataset')
      on.exit({print("eventReactive ts_ar -->"); flush.console()})
      ar
    }, label = "ts_ar")
  
  
  # Reactive value for indexing saved projections plot
  prj_plot_id <- reactiveVal(0)
  
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
      on.exit({print("observeEvent encoders list encs_l | update dataset list -->"); flush.console()})
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
    on.exit(
      {print("observeEvent input_dataset | update encoder list -->"); flush.console()}
    )
  }, label = "input_encoder")
  
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
      updateSliderInput(
        session = session, inputId = "stride", 
        min = 1, max = input$wlen, 
        value = enc_ar_stride()
      )
      on.exit({print("observeEvent input_encoder | update wlen -->"); flush.console()})
    }
  )
  
  # Obtener el valor de stride
  enc_ar_stride = reactive({
    print("--> reactive enc_ar_stride")
    stride = ceiling(enc_ar()$metadata$mvp_ws[2]/2)  #<- enc_ar()$metadata$stride
    on.exit({print(paste0("reactive_enc_ar_stride | --> ", stride)); flush.console()})
    stride
  })
  
  observeEvent(input$wlen, {
    req(input$wlen)
    print(paste0("--> observeEvent input_wlen | update slide stride value | wlen ",  input$wlen))
    tryCatch({
      old_value = input$stride
      if (input$stride == 0 | input$stride == 1){
        old_value = enc_ar_stride()
        print(paste0("enc_ar_stride: ", old_value))
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
    on.exit({print(paste0( 
      "observeEvent input_wlen | update slide stride value | Finally |  wlen min ",  
      1, " max ", input$wlen, " current value ", input$stride, " -->")); flush.console()})
  })
  
  # Update "metric_hdbscan" selectInput when the app is loaded
  observe({
    updateSelectInput(
      session = session,
      inputId = "metric_hdbscan",
      choices = names(req(hdbscan_metrics))
    )
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
    on.exit({print("--> observeEvent tsdf | update select variables -->"); flush.console()})
    freezeReactiveValue(input, "select_variables")
    #ts_variables$selected = names(tsdf())[names(tsdf()) != "timeindex"]
    ts_variables$selected = names(isolate(tsdf()))
    print(paste0("observeEvent tsdf | select variables ", ts_variables$selected))
    updateCheckboxGroupInput(
      session = session,
      inputId = "select_variables",
      choices = ts_variables$selected,
      selected = ts_variables$selected
    )
  }, label = "select_variables")
  
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
    #on.exit({print("observe event calculate_clusters | update clusters_config -->"))
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
    ts_variables$selected <- names(isolate(tsdf()))
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
  # Observe to update encoder input (enc_input = X())
  observe({ #Event(input$dataset, input$encoder, input$wlen, input$stride, {
    req(input$wlen != 0, input$stride != 0, input$stride != 1)
    print(paste0("Check reactiveness | X |  wlen, stride |"))
    if (
      is.null(X()) ||
      !identical(
        input$dataset, isolate(input$dataset)) || 
      !identical(input$encoder, isolate(input$encoder)) || 
      input$wlen != isolate(input$wlen) || 
      input$stride != isolate(input$stride)
    ) {
      print("--> ReactiveVal X | Update Sliding Window")
      print(paste0("reactive X | wlen ", input$wlen, " | stride ", input$stride, " | Let's prepare data"))
      print("reactive X | SWV")
      
      t_x_0 <- Sys.time()
      
      enc_input = dvats$exec_with_feather_k_output(
        function_name = "prepare_forecasting_data",
        module_name   = "tsai.data.preparation",
        path = file.path(DEFAULT_PATH_WANDB_ARTIFACTS, ts_ar()$metadata$TS$hash),
        k_output = as.integer(0),
        print_flag = TRUE,
        time_flag = TRUE,
        fcst_history = input$wlen
      )
      
      t_x_1 <- Sys.time()
      t_sliding_window_view = t_x_1 - t_x_0
      print(paste0("reactive X | SWV: ", t_sliding_window_view, " secs "))
      
      print(paste0("reactive X | Update sliding window | Apply stride ", input$stride," | enc_input ~ ", dim(enc_input), "-->"))
      print("| Update | X" )
      on.exit({print("| Outside| X"); flush.console()})
      X(enc_input)
    }
    X()
  })
  
  ###############
  #  REACTIVES  #
  ###############
  
  # Get timeseries artifact metadata
  ts_ar_config = reactive({
    print("--> reactive ts_ar_config | List used artifacts")
    ts_ar = req(ts_ar())
    print(paste0("reactive ts_ar_config | List used artifacts | hash", ts_ar$hash))
    list_used_arts = ts_ar$metadata$TS
    list_used_arts$vars = ts_ar$metadata$TS$vars %>% stringr::str_c(collapse = "; ")
    list_used_arts$name = ts_ar$name
    list_used_arts$aliases = ts_ar$aliases
    list_used_arts$artifact_name = ts_ar$name
    list_used_arts$id = ts_ar$id
    list_used_arts$created_at = ts_ar$created_at
    list_used_arts
    on.exit({print("reactive ts_ar_config -->"); flush.console()})
  })
  
  # Get encoder artifact
  enc_ar <- eventReactive (
    input$encoder, 
    {
      print(paste0("eventReactive enc_ar | Enc. Artifact: ", input$encoder))
      result <- tryCatch({
        api$artifact(input$encoder, type = 'learner')
      }, error = function(e){
        print(paste0("eventReactive enc_ar | Error: ", e$message))
        NULL
      })
      on.exit({print("envent reactive enc_ar -->"); flush.console()})
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
      on.exit({print("eventReactive enc | load encoder -->"); flush.console()})
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
    t_embs_0 <- Sys.time()
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
    #chunk_max = 10000000
    #shape <- dim(enc_input)
    #print(paste0("reactive embs | get embeddings (set stride set batch size) | enc_input shape: ", shape ))
    #chunk_size_ = min(shape[1]*shape[2],chunk_max/(shape[1]*shape[2]))
    #N = max(3200,floor(chunk_size_/32))
    chunk_size = 10000000 #N*32
    #print(paste0("reactive embs | get embeddings (set stride set batch size) | Chunk_size ", chunk_size, " | shape[1]*shape[2]: ", shape[1]*shape[2] ))
    print(paste0("reactive embs | get embeddings (set stride set batch size) | Chunk_size ", chunk_size))
    #        python_string = paste0("
    #import dvats.all   
    cpu_flag = ifelse(input$cpu_flag == "CPU", TRUE, FALSE)
    result = dvats$get_enc_embs_set_stride_set_batch_size(
      X = X(),
      print_flag = TRUE,
      enc_learn = enc_l,
      stride =  input$stride,  
      batch_size = bs, 
      cpu = cpu_flag, 
      print_flag = FALSE, 
      time_flag = TRUE, 
      chunk_size = chunk_size,
      check_memory_usage = TRUE
    )
    
    #result <- system(python_string)
    #------------------------------------------------
    num_columns <- ncol(result)
    print(paste("--------------------------ncol2 ", num_columns))
    #-------------------------------------------------------------------
    t_embs_1 <- Sys.time()
    diff <- t_embs_1 - t_embs_0
    diff_secs <- as.numeric(diff, units = "secs")
    diff_mins <- as.numeric(diff, units = "mins")
    print(paste0("get_enc_embs total time: ", diff_secs, " secs thus ", diff_mins, " mins"))
    X <- NULL
    gc(verbose=TRUE)
    on.exit({print("reactive embs | get embeddings -->"); flush.console()})
    result
  })
  
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
                    random_state= as.integer(input$prj_random_state),
                    n_components = as.integer(3)
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
    colnames(res) = c("xcoord", "ycoord", "zcoord")
    on.exit({print(" prj_object -->"); flush.console()})
    flush.console()
    #browser()
    res
  })
  
  prj_object <- reactive({
    req(embs(), input$dr_method)
    print("--> prj_object")
    t_prj_0 = Sys.time()
    embs = req(embs())
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
                    random_state= as.integer(input$prj_random_state),
                    n_components = as.integer(3)
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
    #-----------------------------------------------------------------------------------
    #print(paste("---------------------ncol", ncol(res)))
    #print(res)
    #-----------------------------------------------------------------------------------
    res = res %>% as.data.frame # TODO: This should be a matrix for improved efficiency
    colnames(res) = c("xcoord", "ycoord", "zcoord")
    t_prj_1 = Sys.time()
    on.exit({print(paste0(" prj_object | ", t_prj_1-t_prj_0, " seconds -->")); flush.console()})
    flush.console()
    res
  })
  
  
  
  # Load and filter TimeSeries object from wandb
  tsdf <- reactive(
    {    
      req(input$encoder, ts_ar())
      ts_ar <- req(ts_ar())
      print(paste0("--> Reactive tsdf | ts artifact ", ts_ar))
      flush.console()
      
      t_init <- Sys.time()
      path = file.path(DEFAULT_PATH_WANDB_ARTIFACTS, ts_ar$metadata$TS$hash)
      print(paste0("Reactive tsdf | Read feather ", path ))
      flush.console()
      df <- read_feather(path, as_data_frame = TRUE, mmap = TRUE) %>% rename('timeindex' = `__index_level_0__`) 
      t_end = Sys.time()
      print(paste0("Reactive tsdf | Read feather | Execution time: ", t_end - t_init, " seconds"))
      flush.console()
      
      t_end = Sys.time()
      on.exit({print(paste0("Reactive tsdf | Column to index | Execution time: ", t_end - t_init, " seconds"));flush.console()})
      df
    })
  
  # Auxiliary object for the interaction ts->projections
  tsidxs_per_embedding_idx <- reactive({
    req(input$wlen != 0, input$stride != 0)
    get_window_indices(1:nrow(isolate(projections())), w = input$wlen, s = input$stride)
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
    #------------------------------------------
    num_columns <- ncol(prjs)
    print(paste("----------------", num_columns))
    #------------------------------------------
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
             score = 0
             unique_labels <- unique(clusters$labels_)
             total_unique_labels <- length(unique_labels)
             if(total_unique_labels > 1){
               score = dvats$cluster_score(prjs, clusters$labels_, TRUE)
             }
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
               score = 0
               unique_labels <- unique(clusters$labels_)
               total_unique_labels <- length(unique_labels)
               if(total_unique_labels > 1){
                 score = dvats$cluster_score(prjs, clusters$labels_, TRUE)
               }
               print(paste0("Projections | Repeat projections with CPU because of low quality clusters | score ", score))
             }
             prjs$cluster <- clusters$labels_
             
           })
    
    on.exit({print("Projections -->"); flush.console()})
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
  
  color_palete_window_plot <- colorRampPalette(
    colors = c("blue", "green"),
    space = "Lab" # Option used when colors do not represent a quantitative scale
  )
  
  start_date <- reactive({
    isolate(tsdf())$timeindex[1]
  })
  
  end_date <- reactive({
    end_date_id = 100000
    end_date_id = min(end_date_id, nrow(isolate(tsdf())))
    isolate(tsdf())$timeindex[end_date_id]
  })
  
  ts_plot_base <- reactive({
    print("--> ts_plot_base")
    on.exit({print("ts_plot_base -->"); flush.console()})
    start_date =isolate(start_date())
    end_date = isolate(end_date())
    print(paste0("ts_plot_base | start_date: ", start_date, " end_date: ", end_date))
    t_init <- Sys.time()
    tsdf_ <- isolate(tsdf()) %>% select(ts_variables$selected, - "timeindex")
    tsdf_xts <- xts(tsdf_, order.by = tsdf()$timeindex)
    t_end <- Sys.time()
    print(paste0("ts_plot_base | tsdf_xts time", t_end-t_init)) 
    print(head(tsdf_xts))
    print(tail(tsdf_xts))
    ts_plt = dygraph(
      tsdf_xts,
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
  
  # Reactive to store selected points
  selected_points <- reactive({
    event_data("plotly_selected", source = "projections_plot")
  })
  
  # Handle plotly brush event
  embedding_ids <- reactive({
    print("--> embedding idx")
    on.exit(print("embedding idx -->"))
    bp <- selected_points()
    if (is.null(bp)) {
      return(integer(0))
    } else {
      bp$pointNumber + 1  # Adjusting for 0-based index
    }
  })
  
  window_list <- reactive({
    print("--> window_list")
    on.exit(print("window_list -->"))
    # Get the window indices
    req(length(embedding_ids() > 0))
    embedding_idxs = embedding_ids()
    window_indices = get_window_indices(embedding_idxs, input$wlen, input$stride)
    # Put all the indices in one list and remove duplicates
    unlist_window_indices = unique(unlist(window_indices))
    # Calculate a vector of differences to detect idx where a new window should be created 
    diff_vector <- diff(unlist_window_indices,1)
    # Take indexes where the difference is greater than one (that represent a change of window)
    idx_window_limits <- which(diff_vector!=1)
    # Include the first and last index to have a whole set of indexes.
    idx_window_limits <- c(1, idx_window_limits, length(unlist_window_indices))
    # Create a reduced window list
    reduced_window_list <-  vector(mode = "list", length = length(idx_window_limits)-1)
    # Populate the first element of the list with the idx of the first window.
    reduced_window_list[[1]] = c(
      isolate(tsdf())$timeindex[unlist_window_indices[idx_window_limits[1]+1]],
      isolate(tsdf())$timeindex[unlist_window_indices[idx_window_limits[2]]]
    ) 
    if (length(idx_window_limits) > 2) {
      # Populate the rest of the list
      for (i in 2:(length(idx_window_limits)-1)){
        reduced_window_list[[i]]<- c(
          #unlist_window_indices[idx_window_limits[i]+1],
          #unlist_window_indices[idx_window_limits[i+1]]
          isolate(tsdf())$timeindex[unlist_window_indices[idx_window_limits[i]+1]],
          isolate(tsdf())$timeindex[unlist_window_indices[idx_window_limits[i+1]]]
        )
      }
    }
    reduced_window_list
  })
  
  # Reactive expression to generate ts_plot
  ts_plot <- reactive({
    print("--> ts_plot | Before req 1")
    on.exit({print("ts_plot -->"); flush.console()})
    
    req(tsdf(), ts_variables, input$wlen != 0, input$stride)
    
    ts_plt <- ts_plot_base()   
    
    print("ts_plot | bp")
    #miliseconds <-  ifelse(nrow(tsdf()) > 1000000, 2000, 1000)
    
    #if (!is.data.frame(bp)) {bp = bp_}
    print("ts_plot | embedings idxs ")
    embedding_idxs <- embedding_ids()
    # Calculate windows if conditions are met (if embedding_idxs is !=0, that means at least 1 point is selected)
    print("ts_plot | Before if")
    if ((length(embedding_idxs) != 0) & isTRUE(input$plot_windows)) {
      reduced_window_list <- req(window_list())
      print(paste0("ts_plot | reduced_window_list[1] = ", reduced_window_list[1]))
      start_indices <- min(sapply(reduced_window_list, function(x) x[1]))
      end_indices <- max(sapply(reduced_window_list, function(x) x[2]))
      
      view_size <- end_indices - start_indices + 1
      max_size <- 10000
      
      start_date <- isolate(tsdf())$timeindex[start_indices]
      end_date <- isolate(tsdf())$timeindex[end_indices]
      
      print(paste0("ts_plot | reduced_window_list (", start_date, end_date, ")", "view size ", view_size, "max size ", max_size))
      
      if (view_size > max_size) {
        end_date <- isolate(tsdf())$timeindex[start_indices + max_size - 1]
        #range_color = "#FF0000" # Red
      } 
      
      range_color <- "#CCEBD6" # Original
      
      # Plot the windows
      count <- 0
      for (ts_idxs in reduced_window_list) {
        count <- count + 1
        start_event_date <- isolate(tsdf())$timeindex[head(ts_idxs, 1)]
        end_event_date <- isolate(tsdf())$timeindex[tail(ts_idxs, 1)]
        ts_plt <- ts_plt %>% dyShading(
          from = start_event_date,
          to = end_event_date,
          color = range_color
        ) 
        ts_plt <- ts_plt %>% dyRangeSelector(c(start_date, end_date))
      }   
      
      ts_plt <- ts_plt
    }
    
    ts_plt
  })
  
  # Get projections plot name for saving
  prjs_plot_name <- reactive({
    dataset_name <- basename(input$dataset)
    encoder_name <- basename(input$encoder)
    get_prjs_plot_name(dataset_name, encoder_name, clustering_options$selected, prjs_$cluster, prj_plot_id, input)
  })
  
  # Get timeserie plot name for saving
  ts_plot_name <- reactive({
    dataset_name <- basename(input$dataset)
    encoder_name <- basename(input$encoder)
    get_ts_plot_name(dataset_name, encoder_name, prj_plot_id, input)
  })
  
  #############
  #  OUTPUTS  #
  #############
  
  output$windows_plot <- renderPlot({
    req(length(embedding_ids()) > 0)
    reduced_window_list = req(window_list())
    
    # Convertir a fechas POSIXct
    reduced_window_df <- do.call(rbind, lapply(reduced_window_list, function(x) {
      data.frame(
        start = as.POSIXct(isolate(tsdf())$timeindex[x[1]], origin = "1970-01-01"),
        end = as.POSIXct(isolate(tsdf())$timeindex[x[2]], origin = "1970-01-01")
      )
    }))
    
    # Establecer límites basados en los datos
    first_date = min(reduced_window_df$start)
    last_date = max(reduced_window_df$end)
    
    left = as.POSIXct(isolate(tsdf())$timeindex[1],  origin = "1970-01-01")
    right = as.POSIXct(isolate(tsdf())$timeindex[nrow(isolate(tsdf()))], origin = "1970-01-01")
    
    # Configuración del gráfico base
    par(mar = c(5, 4, 4, 0) + 0.1)  #Down Up Left Right
    plt <- plot(
      NA, 
      xlim = c(left, right), 
      ylim = c(0, 1), 
      type = "n", 
      xaxt = "n", yaxt = "n", 
      xlab = "", ylab = "", 
      bty = "n")
    f = "%F %H:%M:%S"
    axis(1, at = as.numeric(c(left, right)), labels = c(format(first_date, f), format(last_date, f)), cex.axis = 0.7)
    
    # Añadir líneas verticales
    colors = color_palete_window_plot(2)
    abline(
      v = as.numeric(reduced_window_df$start), 
      col =  rep(colors, length.out = nrow(reduced_window_df)),
      lwd = 1
    )
    abline(
      v = as.numeric(reduced_window_df$end), 
      col =  rep(colors, length.out = nrow(reduced_window_df)),
      lwd = 1
    )
    segments(
      x0 = as.numeric(reduced_window_df$start),
      x1 = as.numeric(reduced_window_df$end),
      y0 = 0,
      y1 = 0,
      col =  rep(colors, length.out = nrow(reduced_window_df)),
      lwd = 1
    )
    text(
      x = as.numeric(reduced_window_df$start),
      y = 0,
      srt = 90,
      adj = c(1,0.5),
      labels =  paste0("SW-", seq_len(nrow(reduced_window_df)), format(reduced_window_df$start, f)), 
      cex = 1,
      xpd = TRUE,
      col = rep(colors, length.out = nrow(reduced_window_df))
    )
    
    points(x = as.numeric(left),y = 0, col = "black", pch = 20, cex = 1)
    points(x = as.numeric(right),y = 0, col = "black", pch = 20, cex = 1)
    plt
  }, 
  height=200
  )  
  
  output$windows_text <- renderUI({
    req(length(embedding_ids()) > 0)
    reduced_window_list = req(window_list())
    
    # Crear un conjunto de etiquetas de texto con información de las ventanas
    window_info <- lapply(1:length(reduced_window_list), function(i) {
      window <- reduced_window_list[[i]]
      start <- format(as.POSIXct(isolate(tsdf())$timeindex[window[1]], origin = "1970-01-01"), "%b %d")
      end <- format(as.POSIXct(isolate(tsdf())$timeindex[window[2]], origin = "1970-01-01"), "%b %d")
      color <- ifelse(i %% 2 == 0, "green", "blue")
      HTML(paste0("<div style='color: ", color, "'>Window ", i, ": ", start, " - ", end, "</div>"))
    })
    
    # Devuelve todos los elementos de texto como una lista de HTML
    do.call(tagList, window_info)
  })
  
  # Generate encoder info table
  output$enc_info = renderDataTable({
    selected_encoder_name <- req(input$encoder)
    on.exit({print("Encoder artiffact -->"); flush.console()})
    print(paste0("--> Encoder artiffact", selected_encoder_name))
    selected_encoder <- encs_l[[selected_encoder_name]]
    encoder_metadata <- req(selected_encoder$metadata)
    print(paste0("Encoder artiffact | encoder metadata ", selected_encoder_name))
    encoder_metadata %>%enframe()
  })
  
  # Generate time series info table
  output$ts_ar_info = renderDataTable({
    ts_ar_config() %>% enframe()
  })
  
  ranges <- reactiveValues(x = NULL, y = NULL)
  
  # Generate projections plot
  output$projections_plot <- renderPlotly({
    req(input$dataset, input$encoder, input$wlen != 0, input$stride != 0)
    print("--> Projections_plot")
    prjs_ <- req(projections())
    print("projections_plot | Prepare column highlights")
    
    # Prepare the column highlight to color data
    if (!is.null(input$ts_plot_dygraph_click)) {
      selected_ts_idx <- which(ts_plot()$x$data[[1]] == input$ts_plot_dygraph_click$x_closest_point)
      projections_idxs <- tsidxs_per_embedding_idx() %>% map_lgl(~ selected_ts_idx %in% .)
      prjs_$highlight <- projections_idxs
    } else {
      prjs_$highlight <- FALSE
    }
    
    # Prepare the column highlight to color data. If input$generate_cluster has not been clicked
    # the column cluster will not exist in the dataframe, so we create with the value FALSE
    if(!("cluster" %in% names(prjs_)))
      prjs_$cluster <- FALSE
    
    print("projections_plot | GoGo Plot!")
    plt <- ggplot(data = prjs_) + 
      aes(x = xcoord, y = ycoord, fill = highlight, color = as.factor(cluster)) + 
      scale_colour_manual(name = "clusters", values = req(update_palette())) +
      geom_point(shape = 21, alpha = config_style$point_alpha, size = config_style$point_size) + 
      scale_shape(solid = FALSE) +
      guides() + 
      scale_fill_manual(values = c("TRUE" = "green", "FALSE" = "NA")) +
      coord_cartesian(xlim = ranges$x, ylim = ranges$y, expand = TRUE) +
      theme_void() + 
      theme(legend.position = "none")
    
    if (input$show_lines) {
      plt <- plt + geom_path(linewidth = config_style$path_line_size, colour = "#2F3B65", alpha = config_style$path_alpha)
    }
    
    observeEvent(input$savePlot, {
      plt <- plt + theme(plot.background = element_rect(fill = "white"))
      ggsave(filename = prjs_plot_name(), plot = plt, path = "../data/plots/")
    })
    
    # Convert ggplot to plotly
    ggplotly(plt, source = "projections_plot") %>%
      config(scrollZoom = TRUE) %>%
      event_register("plotly_selected")
  })
  
  # Render projections plot UI
  output$projections_plot_ui <- renderUI({
    plotlyOutput(
      "projections_plot", 
      height = input$embedding_plot_height
    ) %>% withSpinner()
  })
        
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


    embedding_3d <- reactive({

      prj <- req(projections())
      print("------------------------------")
      str(embedding_ids)
      print("------------------------------")

      prj_3d <- prj[, 1:3]  
      colnames(prj_3d) <- c("xcoord", "ycoord", "zcoord")
      prj_3d
    })

    selected_point <- reactiveVal(NULL)
    
    points_in_radius <- reactiveVal(NULL)
    
    output$embedding_plot_3d <- renderPlotly({
      prj_3d <- embedding_3d()
      
      # Define colores iniciales
      initial_colors <- rep("black", nrow(prj_3d))
      
      plot <- plot_ly(
        data = prj_3d,
        x = ~xcoord, y = ~ycoord, z = ~zcoord,
        type = "scatter3d",
        mode = "markers",
        marker = list(color = initial_colors, size = 5),
        line = list(color = "blue"),
        showlegend = FALSE
      )
      
      plot %>%
        event_register("plotly_click")
    })
    
    observeEvent(event_data("plotly_click"), {
      click_data <- event_data("plotly_click")
      if (!is.null(click_data)) {
        point_idx <- click_data$pointNumber + 1
        selected_point(point_idx)
        
        prj_3d <- embedding_3d()
        selected_coords <- prj_3d[point_idx, ]
        
        # Calcula la distancia euclidiana
        distances <- sqrt((prj_3d$xcoord - selected_coords$xcoord)^2 + 
                            (prj_3d$ycoord - selected_coords$ycoord)^2 + 
                            (prj_3d$zcoord - selected_coords$zcoord)^2)
        
        # Define el radio
        radius <- 0.5  # ajusta este valor según sea necesario
        radius_idxs <- which(distances <= radius)
        points_in_radius(radius_idxs)
        
        # Actualiza los colores de los puntos
        new_colors <- rep("black", nrow(prj_3d))
        new_colors[radius_idxs] <- "blue"
        new_colors[point_idx] <- "red"
        
        plotlyProxy("embedding_plot_3d", session) %>%
          plotlyProxyInvoke("restyle", list(marker = list(color = new_colors, size = 5)), list(0))
      }
    })
    
    observe({
      if (is.null(input$toggle_graph)) {
        updateNumericInput(session, "toggle_graph", value = 0)
      }
    })
    
    shinyFileChoose(input, "file", roots = c(wd = "~"))
    
    observeEvent(input$load_dataset, {
      showModal(modalDialog(
        title = "Upload Dataset",
        shinyFilesButton("file", "Select a file", title = "Please select a file:", multiple = FALSE),
        textOutput("file_path_text"),
        tags$hr(),
        h4("Configuration"),
        numericInput("cols_input", "Cols:", value = 5, min = 1),
        numericInput("freq_input", "Freq:", value = 10, min = 1),
        numericInput("n_epoch_input", "n_epoch:", value = 100, min = 1),
        numericInput("ws1_input", "ws1:", value = 10, min = 1),
        tags$hr(),
        footer = tagList(
          actionButton("load_file", "Load"),
          modalButton("Cancel")
        )
      ))
    })
    
    observe({
      req(input$file)
      output$file_path_text <- renderText({
        parseFilePaths(roots = c(wd = "~"), input$file)$datapath
      })
    })
    
    observeEvent(input$load_file, {
      filepath <- isolate(parseFilePaths(roots = c(wd = "~"), input$file)$datapath)
      if (length(filepath) > 0) {
        showModal(modalDialog(
          title = "Loading...",
          tagList(
            div(style = "display: flex; align-items: center; flex-direction: column; height: 300px;",
                addSpinner(div(style = "margin-bottom: 200px;", textOutput("progress_text")), spin = "circle",  color = "#007bff"),
                div(style = "width: 80%; margin-top: 60px;", progressBar(id = "progress_bar", value = 0))
            )
          ),
          footer = NULL,
          size = "l" 
        ))
        mod_file_base(filepath)
        mod_file_02encodermvp(filepath)
        updateProgressBar(session, "progress_bar", value = 33, total = 100, status = "info")
        execution_notebooks()
        
      }
      removeModal()
    })
    
    get_parameters <- function(nb_id) {
      switch(nb_id,
        "1" = {
          filename <- "01_dataset_artifact"
          parameters <- list(
            print_flag = FALSE,
            show_plots = FALSE,
            reset_kernel = FALSE,
            pre_configured_case = FALSE,
            case_id = NULL,
            frequency_factor = 1,
            frequency_factor_change_alias = TRUE,
            cuda_device = torch::cuda_current_device()
          )
        },
        "2" = {
          filename <- "02c_encoder_MVP-sliding_window_view"
          parameters <- list(
            print_flag = FALSE,
            check_memory_usage = FALSE,
            time_flag = FALSE,
            window_size_percentage = NULL,
            show_plots = FALSE,
            reset_kernel = FALSE,
            pre_configured_case = FALSE,
            case_id = NULL,
            frequency_factor = 1,
            frequency_factor_change_alias = TRUE,
            cuda_device = torch::cuda_current_device()
          )
        },
        {
          print("Invalid configuration")
          filename <- ""
          parameters <- list()
        }
      )
      return(list(filename, parameters))
    }

    get_input_output <- function(nb_id) {
      params <- get_parameters(nb_id)
      filename <- params[[1]]
      parameters <- params[[2]]
      print(filename)
      print(parameters)  
      
      inbpath <- path.expand("~/work/nbs_pipeline")
      onbpath <- path.expand("~/work/nbs_pipeline/output")
      extension <- ".ipynb"
      reportname <- paste0(filename, "-output")
      inputnb <- file.path(inbpath, paste0(filename, extension))
      outputnb <- file.path(onbpath, paste0(reportname, extension))
      print(paste("Executing", inputnb, "into", outputnb))
      return(list(inputnb, outputnb, parameters))
    }
    
    execution_notebooks <- function() {
      print("------------- START ------------------------")
      nb_path_1 <- "~/work/nbs_pipeline/01_dataset_artifact.ipynb"
      print("--> 1st Jupyter Notebook: start")

      result <- get_input_output(1)
      input_nb <- result[[1]]
      output_nb <- result[[2]]
      parameters <- result[[3]]

      _ <- ploomber::execute_notebook(
        input_path = input_nb,
        output_path = output_nb,
        log_output = FALSE,
        progress_bar = TRUE,
        parameters = parameters,
        remove_tagged_cells = c('skip', 'hide')
      )


      #system(paste("jupyter nbconvert --execute --to notebook --inplace", nb_path_1))
      
      print("First notebook: end -->")
      updateProgressBar(session, "progress_bar", value = 66, total = 100, status = "info")
      
      nb_path_2 <- "~/work/nbs_pipeline/02c_encoder_MVP-sliding_window_view.ipynb"
      print("Se ha inicializado Segundo notebook")
      system(paste("jupyter nbconvert --execute --to notebook --inplace", nb_path_2))
      
      print("El segundo notebook ha finalizado.\n")
      updateProgressBar(session, "progress_bar", value = 100, total = 100, status = "info")
      
      print("Ambos notebooks han finalizado completamente.\n")
      
    }
    
    mod_file_base <- function(filepath){
      yaml_content <- readLines("~/work/nbs_pipeline/config/base.yaml")
      
      file_extension <- tools::file_ext(filepath)
      
      filename <- basename(filepath)
      filename <- tools::file_path_sans_ext(filename)
      
      new_fname <- paste("fname: &fname \"", filename, "\"", sep = "")
      yaml_content <- gsub("fname: &fname \".*\"", new_fname, yaml_content)
      
      new_ftype <- paste("ftype: &ftype \'.", file_extension, "\'", sep = "")
      yaml_content <- gsub("ftype: &ftype \'.*\'", new_ftype, yaml_content)
      
      new_cols <- paste("cols: &cols [", input$cols_input, "]", sep = "")
      new_freq <- paste("freq: &freq '", input$freq_input, "h'", sep = "")
      
      yaml_content <- gsub("cols: &cols \\[.*\\]", new_cols, yaml_content)
      yaml_content <- gsub("freq: &freq '.*'", new_freq, yaml_content)
      
      writeLines(yaml_content, "~/work/nbs_pipeline/base.yaml")
      
      print("Se han anadido las modificaciones al fichero base", sep = "\n")
      print(yaml_content, sep = "\n")
    }
    
    mod_file_02encodermvp <- function(filepath){
      
      yaml_content <- readLines("~/work/nbs_pipeline/config/02c-encoder_mvp-sliding_window_view.yaml")
      
      new_n_epoch <- paste("    n_epoch:", input$n_epoch_input)
      new_ws1 <- paste("      ws1:", input$ws1_input)
      
      yaml_content <- gsub("    n_epoch: .*", new_n_epoch, yaml_content)
      yaml_content <- gsub("      ws1: .*", new_ws1, yaml_content)
      
      writeLines(yaml_content,"~/work/nbs_pipeline/config/02c-encoder_mvp-sliding_window_view.yaml")
      
      print(yaml_content, sep = "\n")
      
      print("Se han anadido las modificaciones a ficheros de configuracion")
    }
    
    
})
