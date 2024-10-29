#
# This is the server logic of a Shiny web application. You can run the
# application by clicking 'Run App' above.
#
# Find out more about building applications with Shiny here:
#
#    http://shiny.rstudio.com/
#
###########
#TODO: Separar la aplicación en módulos y limpiar el código. 
source("./lib/server/logs.R")
source("./lib/server/plots.R")
source("./lib/server/server.R")
source("./modules/parameters.R")
source("./modules/mplots.R")

shinyServer(function(input, output, session) {
    options(shiny.verbose = TRUE)
    #options(shiny.error = function() {
    #    traceback()
    #    stopApp()
  
    ######################
    #  REACTIVES VALUES  #
    ######################
    
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

    update_play_pause_button <- function() {
        if (play()) {
            updateActionButton(session, "play_pause", label = "Pause", icon = shiny::icon("pause"))
            } else {
                updateActionButton(session, "play_pause", label = "Run!", icon = shiny::icon("play"))
            }
    }

    play_fine_tune <- reactiveVal(FALSE)
    update_play_fine_tune_button <- function() {
        log_print(paste0("--> Updating play_fine_tune ", play_fine_tune()))
        play_fine_tune(!play_fine_tune())
        if (play_fine_tune()) {
            updateActionButton(session, "fine_tune_play", label = "Pause", icon = shiny::icon("pause"))
        } else {
            updateActionButton(session, "fine_tune_play", label = "Run!", icon = shiny::icon("play"))
        }
        log_print(paste0(" Updating play_fine_tune --> ", play_fine_tune()))
    }
    observeEvent(input$fine_tune_play, {
        update_play_fine_tune_button()
    })


    observeEvent(input$play_pause, {
        print("--> observeEvent play_pause_button")
        play(!play())
        update_play_pause_button()
        on.exit({print(paste0("observeEvent play_pause_button | Run ", play(), "-->")); flush.console()})
    })
    
    observeEvent(input$cuda, {
        print("--> Cleanning cuda objects")
        torch$cuda$empty_cache()
        print("Cleanning cuda objects -->")
    })

    observeEvent(
        #req(exists("encs_l")), 
        req(exists("data_l")),
        {
            freezeReactiveValue(input, "dataset")
            log_print("observeEvent encoders list enc_l | update dataset list | after freeze")
            updateSelectizeInput(
                session = session,
                inputId = "dataset",
                #choices = encs_l %>% 
                #map(~.$metadata$train_artifact) %>% 
                #set_names()
                choices = sapply(data_l, function(art) art$name)
            )
            on.exit({log_print("observeEvent encoders list encs_l | update dataset list -->"); flush.console()})
        }, 
        label = "input_dataset"
    )
    
    mplot_compute_allow <- reactiveVal(TRUE)

    select_datasetServer(encs_l, mplot_compute_allow, input, output, session)
    
    observeEvent(
        input$encoder,
        {
            log_print(
                mssg = "--> observeEvent input_encoder", 
                file_flag = TRUE, 
                file_path = log_path(),
                log_header =log_header(),
                debug_level, 'main'
            )
            
            freezeReactiveValue(input, "wlen")
            
            log_print("observeEvent input_encoder | update wlen | Before enc_ar", debug_level = debug_level, debug_group = 'generic')
            
            enc_ar = enc_ar()
            
            log_print(paste0("observeEvent input_encoder | update wlen | enc_ar: ", enc_ar, "| Set wlen slider values"), debug_level = debug_level, debug_group = 'generic')
    
            if (is.null(enc_ar$metadata$mvp_ws)) {
                log_print("observeEvent input_encoder | update wlen | Set wlen slider values from w | ", debug_level = debug_level, debug_group = 'generic')
                enc_ar$metadata$mvp_ws = c(enc_ar$metadata$w, enc_ar$metadata$w)
            }
            
            log_print(paste0("observeEvent input_encoder | update wlen | enc_ar$metadata$mvp_ws ", enc_ar$metadata$mvp_ws ), debug_level = debug_level, debug_group = 'generic')
            
            wmin <- enc_ar$metadata$mvp_ws[1]
            wmax <- enc_ar$metadata$mvp_ws[2]
            wlen <- enc_ar$metadata$w
            
            log_print(
                paste0(
                    "observeEvent input_encoder | update wlen | Update slider input (", 
                    wmin, ", ", wmax, " ) -> ", wlen 
                ), debug_level = debug_level, debug_group = 'generic')
            
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
            
            on.exit({
                log_print(
                    paste0(
                        "observeEvent input_encoder | update wlen ",
                        input$wlen,
                        " | stride ",
                        input$stride,
                        " -->"
                        ), 
                FALSE, log_path(), log_header(), debug_level, 'generic'
            ); flush.console()
            })
        }
    )

    ############ WLEN TEXT ############
    observe({
        req(input$wlen_text > 0)
        if (input$wlen != input$wlen_text) {
            # Si se ingresa un valor en wlen_text menor que el mínimo o mayor que el máximo del slider, ajustamos el slider
            if (input$wlen_text < input$wlen || input$wlen_text > input$wlen) {
                updateSliderInput(session, "wlen", 
                    min = min(input$wlen_text, input$wlen), 
                    max = max(input$wlen_text, input$wlen), 
                    value = input$wlen_text)
                }
        }
        allow_update_len(FALSE)
        })

        observe({
            req(input$wlen_text > 0)
            allow_update_len(TRUE)
        })
    ####### --- wlen text ---  ########


    observeEvent(input$restore_wlen_stride, {
        enc_ar = isolate(enc_ar())
         log_print(paste0("observeEvent restore wlen stride | update wlen | enc_ar$metadata$mvp_ws ", enc_ar$metadata$mvp_ws ), debug_level = debug_level, debug_group = 'generic')
            
            wmin <- enc_ar$metadata$mvp_ws[1]
            wmax <- enc_ar$metadata$mvp_ws[2]
            wlen <- enc_ar$metadata$w
            
            log_print(
                paste0(
                    "observeEvent restore wlen stride | update wlen | Update slider input (", 
                    wmin, ", ", wmax, " ) -> ", wlen 
                ), debug_level = debug_level, debug_group = 'generic')
            
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
            
            on.exit({
                log_print(
                    paste0(
                        "observeEvent restore wlen stride ",
                        input$wlen,
                        " | stride ",
                        input$stride,
                        " -->"
                        ), 
                FALSE, log_path(), log_header(), debug_level, 'generic'
            ); flush.console()
            })
    })

    # Obtener el valor de stride
    enc_ar_stride <- eventReactive(enc_ar(),{
        log_print("--> reactive enc_ar_stride", debug_level = debug_level, debug_group = 'generic')
        stride <- enc_ar()$metadata$stride
        on.exit({log_print(paste0("reactive_enc_ar_stride | --> ", stride), debug_level = debug_level, debug_group = 'generic'); flush.console()})
        stride
    })
        
    # Reactive value for ensuring correct dataset
    tsdf_ready <- reactiveVal(FALSE)
    # Reactive value for ensuring correct encoder input
    enc_input_ready <- reactiveVal(FALSE)
    allow_update_len <- reactiveVal(TRUE)
    allow_update_embs <- reactiveVal(FALSE)

    play <- reactiveVal(FALSE)

    observeEvent(input$play_embs, {
        allow_update_embs(!allow_update_embs())
    })


    observeEvent(input$wlen, {
        req(input$wlen)
        log_print(mssg = paste0("--> observeEvent input_wlen | update slide stride value | wlen ",  input$wlen), debug_level = debug_level, debug_group = 'generic')
        tryCatch({
            old_value = input$stride
            if (input$stride == 0 | input$stride == 1){
                old_value = enc_ar_stride()
                log_print(paste0("enc_ar_stride: ", old_value), debug_level = debug_level, debug_group = 'generic')
            }
            
            freezeReactiveValue(input, "stride")
            
            log_print(paste0("oserveEvent input_wlen | update slide stride value | Update stride to ", old_value), debug_level = debug_level, debug_group = 'generic')
        
            updateSliderInput(
                session = session, inputId = "stride", 
                min = 1, max = input$wlen, 
                value = ifelse(old_value <= input$wlen, old_value, 1)
            )

        }, error = function(e){
            log_print(paste0("observeEvent input_wlen | update slide stride value | Error | ", e$message), file_flag = FALSE, file_path = log_path(), log_header = log_header(), debug_level = debug_level, debug_group = 'generic')
        }, warning = function(w) {
            message(paste0("observeEvent input_wlen | update slide stride value | Warning | ", w$message))
        })
        on.exit({
            log_print(paste0( 
            "observeEvent input_wlen | update slide stride value | Finally |  wlen min ",  
            1, " max ", input$wlen, " current value ", input$stride, " -->"), 
            file_flag = FALSE, file_path = log_path(), log_header = log_header(), debug_level = debug_level, debug_group = 'generic'
        ); flush.console()})
    })

    # Update "metric_hdbscan" selectInput when the app is loaded
    observe({
        updateSelectInput(
            session = session,
            inputId = "metric_hdbscan",
            choices = names(req(hdbscan_metrics))
        )
    })
    
    # Update selected time series variables and update interface config
    observeEvent(tsdf(), {
        req(allow_tsdf() == TRUE)
        log_print("--> observeEvent tsdf | update select variables", debug_level = debug_level, debug_group = 'main')
        on.exit({log_print("--> observeEvent tsdf | update select variables -->", debug_level = debug_level, debug_group = 'main'); flush.console()})
        
        ts_variables$selected = names(tsdf())[names(tsdf()) != "timeindex"]
        
        log_print(paste0("observeEvent tsdf | select variables ", ts_variables$selected))
        
        updateCheckboxGroupInput(
            session = session,
            inputId = "select_variables",
            choices = ts_variables$selected,
            selected = ts_variables$selected
        )

    }, label = "select_variables")
       
    # Update precomputed_clusters reactive value when the input changes
    observeEvent(input$clusters_labels_name, {
        log_print("--> observe | precomputed_cluster selected ", debug_level = debug_level, debug_group = 'generic')
        precomputed_clusters$selected <- req(input$clusters_labels_name)
        log_print(paste0("observe | precomputed_cluster selected --> | ", precomputed_cluster$selected), debug_level = debug_level, debug_group = 'generic')
    })
    
    
    # Update clustering_options reactive value when the input changes
    observe({
        log_print("--> Observe clustering options")
        clustering_options$selected <- req(input$clustering_options)
        log_print("Observe clustering options -->")
    })

    
    # Update clusters_config reactive values when user clicks on "calculate_clusters" button
    observeEvent(input$calculate_clusters, {
        send_log("Clusters config_start", session)
        log_print("--> observe event calculate_clusters | update clusters_config")
        clusters_config$metric_hdbscan <- req(input$metric_hdbscan)
        clusters_config$min_cluster_size_hdbscan <- req(input$min_cluster_size_hdbscan)
        clusters_config$min_samples_hdbscan <- req(input$min_samples_hdbscan)
        clusters_config$cluster_selection_epsilon_hdbscan <- req(input$cluster_selection_epsilon_hdbscan)
        send_log("Clusters config_end", session)
        on.exit({log_print("observe event calculate_clusters | update clusters_config -->")})
    })
    
    
    # Observe the events related to zoom the projections graph
    observeEvent(input$zoom_btn, {
        send_log("Zoom btn_start", session)
        log_print("--> observeEvent zoom_btn", debug_level = debug_level, debug_group = 'generic')
        on.exit(log_print(paste0("--> observeEvent zoom_btn ", isTRUE(input$zoom_btn)), debug_level = debug_level, debug_group = 'generic'))
        
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

        send_log("Zoom btn_end", session)
    })
    
    
    # Observe the events related to change the appearance of the projections graph
    observeEvent(input$update_prj_graph,{
        send_log("Update prj graph_start", session)
        log_print("Update prj graph", TRUE, log_path(), log_header())
        
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
        send_log("Update prj graph_end", session)
    })
    
    
    # Update ts_variables reactive value when time series variable selection changes
    observeEvent(input$select_variables, {
        ts_variables$selected <- input$select_variables
    })
    
    
    # Observe to check/uncheck all variables
    observeEvent(input$selectall,{
        send_log("Select all variables_start", session)
        req(tsdf)
        ts_variables$selected <- names(tsdf())
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
        send_log("Select all variables_end", session)
    })

    #observeEvent(list(input$dataset, input$stide, input$wlen, input$patch_size), {
    #    allow_update_embs(TRUE)
    #})

    observeEvent(input$stride, {
        enc_input_ready(FALSE)
    })


    ###############
    #  REACTIVES  #
    ###############

    X <- reactiveVal()
    
    observe({
        log_print(
            paste0("--> Reactive X | Before req | tsdf_ready ", tsdf_ready(), 
            " | wlen ", input$wlen, 
            " | stride ", input$stride
        ))
        req(
            tsdf_ready, 
            input$wlen != 0, 
            input$stride != 0
        )
        log_print("--> Reactive X | Update Sliding Window")
        log_print(paste0("reactive X | wlen ", input$wlen, " | stride ", input$stride, " | Let's prepare data"))
        log_print("reactive X | SWV")
        t_x_0 <- Sys.time()
        if (
            ! enc_input_ready()
        ) { 
            req(play())
            print("Enc input | Update X")
            print("Enc input | --> ReactiveVal X | Update Sliding Window")
            print(paste0("Enc input | reactive X | wlen ", input$wlen, " | stride ", input$stride, " | Let's prepare data"))
            print(paste0("Enc input | reactive X | ts_ar - id ", ts_ar()$id, " - name ", ts_ar()$name))
            ############## SLIDING WINDOW VIEW
            enc_input <- dvats$exec_with_feather_k_output(
                function_name = "prepare_forecasting_data",
                module_name   = "tsai.data.preparation",
                path = file.path(DEFAULT_PATH_WANDB_ARTIFACTS, ts_ar()$metadata$TS$hash),
                k_output = as.integer(0),
                verbose = as.integer(1),
                time_flag = TRUE,
                #tsdf(), #%>%select(-"timeindex"),
                fcst_history = input$wlen
            )
            ### Selecting indexes in the sliding window view version ###
            print(
                paste0("Enc input | reactive X | 1) enc_input ~ ", dim(enc_input))
            )
            indexes <- seq(1, dim(enc_input)[1], input$stride)
            enc_input <- enc_input[indexes,,,drop = FALSE]
            print(
                paste0("Enc input | reactive X | 2) enc_input ~ ", dim(enc_input))
            )
            ############## SLIDING WINDOW (some problem with type conversion when trying to come back)
            #enc_input <- tsai_data$SlidingWindow(window_len = input$wlen, stride = input$stride, get_y = list())(tsdf())[[1]]
            #print(
                #paste0("Enc input | reactive X | 1) enc_input ~ ", dim(enc_input),
                #" | tsdf ~ ", dim(tsdf()))
            #)
            #indexes <- seq(1, dim(enc_input)[1], input$stride)

            #print(
            #    paste0("Enc input | reactive X | 2) enc_input ~ ", dim(enc_input),
            #    " | tsdf ~ ", dim(tsdf()))
            #)
            #####
            print(paste0("Enc input | reactive X | Update sliding window | Apply stride ", input$stride," | X ~ enc_input ~ ", dim(enc_input), "-->"))
            on.exit({print("Enc input | reactive X -->"); flush.console()})
            #browser()
            enc_input_ready(TRUE)
            X(enc_input)
        } else {
            print("Enc input | reactive X | X already updated")
        }

        t_x_1 <- Sys.time() 
        t_sliding_window_view = t_x_1 - t_x_0
        log_print(paste0("reactive X | SWV: ", t_sliding_window_view, " secs "), TRUE, log_path(), log_header())
        temp_log <<- log_add(
            log_mssg            = isolate(temp_log), 
            function_           = "Reactive X | SWV",
            cpu_flag            = isolate(input$cpu_flag),
            dr_method           = isolate(input$dr_method),
            clustering_options  = isolate(input$clustering_options),
            zoom                = isolate(input$zoom_btn),
            time                = t_sliding_window_view,
            mssg                = "Compute Sliding Window View"
        )
        on.exit({
            log_print(paste0(
                "reactive X | Update sliding window | Exit ", 
                input$stride,
                " | enc_input ~ ",
                dim(X()),
                "-->"
            )); flush.console()
        })
        X()
    })
    
    # Time series artifact
    ts_ar <- eventReactive(
        input$dataset, 
        {
        req(input$dataset)
        tsdf_ready(FALSE)
        enc_input_ready(FALSE)
        log_print(paste0("--> eventReactive ts_ar | Update dataset artifact | hash ", input$dataset, "-->"))
        ar <- api$artifact(input$dataset, type='dataset')
        on.exit({log_print("eventReactive ts_ar -->"); flush.console()})
        ar
    }, label = "ts_ar")

    
    log_path <- reactiveVal() 
    log_header <- reactiveVal()
    
    temp_log <- data.frame(
        timestamp           = character(),
        function_           = character(),
        cpu_flag            = logical(),
        dr_method           = character(),
        clustering_options  = character(),
        zoom                = logical(),
        time                = numeric(),
        mssg                = character(),
        stringsAsFactors    = FALSE
    )


    log_df <- reactiveVal(
        data.frame( 
            timestamp           = character(),
            dataset             = character(),
            encoder             = character(),
            execution_id        = numeric(),
            function_           = character(),
            cpu_flag            = character(),
            dr_method           = character(),
            clustering_options  = character(),
            zoom                = logical(),
            point_alpha         = numeric(),
            show_lines          = logical(),
            mssg                = character(),
            time                = numeric()
        )
    )

    observe({
        if (nrow(temp_log) > 0) {
            new_record <- cbind(
                execution_id = execution_id, 
                dataset = isolate(ts_ar()$name),
                encoder = ifelse(is.null(isolate(input$encoder)), " ", input$encoder),
                show_lines = isolate(input$show_lines),
                point_alpha = isolate(input$point_alpha),
                temp_log
            )
            log_df(rbind(new_record, log_df()))
            temp_log <<- data.frame(timestamp = character(), function_ = character(), cpu_flag = character(), dr_method = character(), clustering_options = character(), zoom = logical(), time = numeric(), mssg = character(), stringsAsFactors = FALSE)
        }
        invalidateLater(10000)
    })

    
    

    execution_id = get_execution_id(id_file)

    observe({
        toguether_log_path = paste0(header, "-", execution_id)
        if (toguether){
            log_path(toguether_log_path)
            print(paste0(">>>> Toguether Log path: ", toguether_log_path))   
        } else {
            new_log_path <- paste0(toguether_log_path, "-", ts_ar()$name, ".log")  # Construye el nuevo log_path
            log_path(new_log_path)
            print(paste0(">>>> New Log path: ", new_log_path))   
        }
    })

    
    observe({
        log_header_ = paste0(
            ts_ar()$name, " | ", 
            execution_id ," | ", 
            input$cpu_flag, " | ", 
            input$dr_method, " | ", input$clustering_options, " | ", input$zoom_btn)
        print(paste0(">>>>> Log header: ", log_header_, "<<<<<"))
        log_header(log_header_)  
    })
    
    # Get timeseries artifact metadata
    ts_ar_config = reactive({
        log_print("--> reactive ts_ar_config | List used artifacts")
        on.exit({log_print("reactive ts_ar_config -->"); flush.console()})
        ts_ar = req(ts_ar())
        log_print(paste0("reactive ts_ar_config | List used artifacts | hash", ts_ar$metadata$TS$hash))
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
    
    # selected_embs_ar = eventReactive(input$embs_ar, {
    #   embs_l[[input$embs_ar]]
    # })
    
    # embeddings object. Get it from local if it is there, otherwise download
    # embs = reactive({
    #   selected_embs_ar = req(selected_embs_ar())
    #   log_print("embs")
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
            log_print(paste0("eventReactive enc_ar | Enc. Artifact: ", input$encoder))
            result <- tryCatch({
                api$artifact(input$encoder, type = 'learner')
            }, error = function(e){
                log_print(paste0("eventReactive enc_ar | Error: ", e$message))
                NULL
            })
            on.exit({log_print("envent reactive enc_ar -->"); flush.console()})
            result
        }, 
        ignoreInit = T
    )
   
   # Encoder
    enc <- eventReactive(
        enc_ar(), 
    {
        req(input$dataset, input$encoder)
        log_print("--> eventReactive enc | load encoder ")
        encoder_artifact <- enc_ar()
        encoder_read_option <- ""
        encoder_artifact_dir <- ""
        encoder_filename <- encoder_artifact$metadata$ref$hash
        default_path <- file.path(DEFAULT_PATH_WANDB_ARTIFACTS, encoder_filename)
        enc <- NULL

        print(paste0("eventReactive enc | load encoder | Check if the encoder file exists: ", default_path))

        if (file.exists(default_path)) {
            print(paste0("eventReactive enc | load encoder ", encoder_filename ," | --> Load from binary file "))
            # --- Load from binary file --- #
            encoder_read_option <- "Load from binary file"
            enc <- py_load_object(default_path)

        } else { # If the encoder file has not been found in the default path
            # --- Download from W&B and load from binary file --- #
            encoder_read_option <- "Download from Weights & Biases and load from binary file"
            print(
                paste0(
                    "eventReactive enc | load encoder ",
                    encoder_filename ," | ", 
                    encoder_read_option,
                    " | --> Load from binary file "
                )
            )
            tryCatch({
                print(paste0("eventReactive enc | Download encoder's artifact ",encoder_filename, ", ",enc_ar()$name))
                encoder_artifact_dir <- encoder_artifact$download()
                encoder_artifact_dir
            }, error = function(e){
                stop(
                    paste0(
                        "eventReactive enc | Download encoder's artifact. The encoder artifact ",
                        encoder_filename, ", ",
                        enc_ar()$name,
                        " does not exist in W&B. Looking for the nearest encoder trained with the same dataset. | Error: ", 
                        e$message,
                        "
                        Here we should look for the nearest encoder trained with the same dataset. But it is not yet implemented... 
                        Please just delete the problematic encoder in W&B. \n
                        For some reason, W&B does not find the encoders of MVP-WSV logged in other machines.
                        Please, copy them if possible, or if you need to use another artifact and can delete the first that the app uses, just delete it in W&B.\n
                        "
                    )
                )
                encoder_artifact_dir
            })

            print(paste0("eventReactive enc | Download from Weight & Biases | encoder artifact dir: ", encoder_artifact_dir))

            encoder_path <- file.path(encoder_artifact_dir, encoder_filename)
            print(paste0("eventReactive enc | Download from Weight & Biases | encoder path: ", encoder_path))
            # Move the file to the default path
            file.copy(
                from        = encoder_path, 
                to          = default_path, 
                overwrite   = TRUE, 
                recursive   = FALSE, 
                copy.mode   = TRUE
            )
            # Load from binary file
            enc <- py_load_object(default_path)
            if (is.null(enc)) {
                stop("Encoder null after loading from the binary file. Something went wrong.")
            }
        } # End of else 
        
        
        on.exit({log_print(paste0(
            "eventReactive enc | load encoder | stride ", 
            input$stride, 
            "-->"
        )); flush.console()})
        enc
    })

   

    embs_kwargs <- reactive({
        res <- list()
        dataset <- isolate (X())
        batch_size <- as.integer(dim(dataset)[1])
        encoder <- input$encoder
        cpu_flag = ifelse(input$cpu_flag == "CPU", TRUE, FALSE)
        if (grepl("moment", encoder, ignore.case = TRUE)) {
            log_print("embs_kwargs | Moment")
            res <- list(
                batch_size = batch_size,
                cpu = cpu_flag,
                to_numpy = TRUE,
                verbose = as.integer(1),
                padd_step = input$padd_step, 
                average_seq_dim = TRUE
            )
        } else if (grepl("moirai", encoder, ignore.case = TRUE)) {
            log_print("embs_kwargs | Moirai")
#            size <- sub(".*moirai-(\\w+).*", "\\1", encoder)

            res <- list(
                cpu = cpu_flag,
                to_numpy = TRUE,
                batch_size = batch_size,
                average_seq_dim = TRUE,
                verbose = as.integer(2),
                patch_size = as.integer(input$patch_size),
                time = TRUE
            )
        } else {
            log_print("embs_kwargs | Learner (neither Moment or Moirai)")
            res <- list(
               stride = as.integer(input$stride),
               cpu = cpu_flag,
               to_numpy = TRUE,
               batch_size = batch_size,
               average_seq_dim = TRUE,
               verbose = as.integer(1)
           )
        }
        res
    })

    fine_tune_kwargs <- reactive({
        res <- list()
        dataset <- isolate (X())
        batch_size <- as.integer(input$ft_batch_size)
        encoder <- input$encoder
        percent <- input$ft_window_percent_value
        cpu_flag = ifelse(input$cpu_flag == "CPU", TRUE, FALSE)
        if (grepl("moment", encoder, ignore.case = TRUE)) {
            log_print("embs_kwargs | Moment")
            res <- list(
                batch_size = batch_size,
                cpu = cpu_flag,
                to_numpy = TRUE,
                verbose = as.integer(2),
                padd_step = input$padd_step, 
                average_seq_dim = TRUE,
                percent = percent
            )
        } else if (grepl("moirai", encoder, ignore.case = TRUE)) {
            log_print("embs_kwargs | Moirai")
#            size <- sub(".*moirai-(\\w+).*", "\\1", encoder)

            res <- list(
                cpu = cpu_flag,
                to_numpy = TRUE,
                batch_size = batch_size,
                average_seq_dim = TRUE,
                verbose = as.integer(2),
                patch_size = as.integer(input$patch_size),
                time = TRUE
            )
        } else {
            log_print("embs_kwargs | Learner (neither Moment or Moirai)")
            res <- list(
               stride = as.integer(input$stride),
               cpu = cpu_flag,
               to_numpy = TRUE,
               batch_size = batch_size,
               average_seq_dim = TRUE,
               verbose = as.integer(1)
           )
        }
        res
    })

    ####  CACHING EMBEDDINGS ####
    # TODO: Conseguir que funcione el cache, sigue recalculando todo
    embs_first_comp <- reactiveVal(TRUE)

    cached_embeddings <- reactiveVal(NULL)
    last_inputs <- reactiveVal(
        list (
            dataset = NULL,
            encoder = NULL,
            wlen    = NULL,
            stride  = NULL,
            fine_tune = NULL
        )
    )
    embs <- reactive({
        current_inputs <- list(
            dataset   = input$dataset,
            encoder   = input$encoder,
            wlen      = input$wlen,
            stride    = input$stride,
            fine_tune = input$fine_tune
        )
        if (embs_first_comp() || ! identical(current_inputs, last_inputs())){
            shinyjs::enable("embs_comp")
            log_print("|| Embs || First embedding computation, skipping cache")
            embs_first_comp(FALSE)
            res <- embs_comp()
            cached_embeddings(res)
            shinyjs::disable("embs_comp")
        } else {
            log_print("|| Embs || Use cached")
            last_inputs(current_inputs)
            res <- isolate(embs_comp())
        }
        log_print(paste0("|| embs res ||", dim(res)))
        res
    })
    ###########################

    
        
    embs_comp <- reactive({
        print(paste0(
            "--> reactive embs (before req) | get embeddings | enc_input_ready ", enc_input_ready()," | play " , play()))
        req(tsdf(), X(), enc_l <- enc(), enc_input_ready(), allow_update_embs())
        
        print(paste0("--> reactive embs (after req) | get embeddings | enc_input_ready ", enc_input_ready()))
        print(paste0("tsdf ~ ", dim(tsdf())))
        print(paste0("X ~ ", dim(X())))
        log_print("--> reactive embs | get embeddings")
        if (torch$cuda$is_available()){
            log_print(paste0("CUDA devices: ", torch$cuda$device_count()))
          } else {
            log_print("CUDA NOT AVAILABLE")
        }
        t_embs_0 <- Sys.time()
        log_print(
            paste0(
                "reactive embs | get embeddings | Just about to get embedings. Device number: ", 
                torch$cuda$current_device() 
            )
        )
        
        log_print("reactive embs | get embeddings | Get batch size and dataset")

        dataset_logged_by <- enc_ar()$logged_by()
        bs = dataset_logged_by$config$batch_size
        stride = input$stride 
        
        print(paste0("reactive embs | get embeddings (set stride set batch size) | Stride ", input$stride, " | batch size: ", bs , " | stride: ", stride))
        print(paste0("reactive embs | get embeddings | Original stride: ", dataset_logged_by$config$stride))
        enc_input <- X()
        
        chunk_size = 10000000 #N*32
        
        log_print(paste0("reactive embs | get embeddings (set stride set batch size) | Chunk_size ", chunk_size))
        log_print(paste0("reactive embs | get_enc_embs_set_stride_set_batch_size | ", input$cpu_flag, " | Before"))
        specific_kwargs <- embs_kwargs()
        
        kwargs_common <- list(
            X                   = enc_input,
            enc_learn           = enc_l,
            verbose             = as.integer(1)
        )
        kwargs <- c(kwargs_common, list(stride = as.integer(input$stride)), specific_kwargs)
        
        result <- do.call(
                    dvats$get_enc_embs_set_stride_set_batch_size,
                    kwargs
                )
     
        log_print(paste0("reactive embs | get_enc_embs_set_stride_set_batch_size | ", input$cpu_flag, " | After"))
        log_print(paste0("reactive embs | get_enc_embs_set_stride_set_batch_size embs ~ | ", dim(result) ))
        t_embs_1 <- Sys.time()
        diff <- t_embs_1 - t_embs_0
        diff_secs <- as.numeric(diff, units = "secs")
        diff_mins <- as.numeric(diff, units = "mins")
        log_print(paste0(
            "get_enc_embs_set_stride_set_batch_size | ", 
            input$cpu_flag, 
            " | total time: ", 
            diff_secs, 
            " secs thus ", 
            diff_mins, 
            " mins | result ~", dim(result)
            ), TRUE, log_path(), log_header()
        )
        temp_log <<- log_add(
            log_mssg            = temp_log, 
            function_           = "Embeddings",
            cpu_flag            = isolate(input$cpu_flag),
            dr_method           = isolate(input$dr_method),
            clustering_options  = isolate(input$clustering_options),
            zoom                = isolate(input$zoom_btn),
            time                = diff, 
            mssg                = "Get encoder embeddings"
        )
        X <- NULL
        gc(verbose=as.integer(1))
        on.exit({log_print("reactive embs | get embeddings -->"); flush.console()})
        log_print("...Cleaning GPU")
        rm(enc_l, enc_input)
        log_print(paste0("Cleaning GPU... || ", dim(result)))
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

observe({
    log_print("Observe event | Input fine tune | Play fine tune ... Waiting ...")
    req(play_fine_tune(), input$fine_tune)
    log_print("Observe event | Input fine tune | Play fine tune")

    if (grepl("moment", input$encoder, ignore.case = TRUE)) {
        fine_tune_kwargs <- list(
            X                               = isolate(tsdf()) %>% select(-timeindex),
            enc_learn                       = isolate(enc()),
            stride                          = as.integer(1),
            batch_size                      = as.integer(input$ft_batch_size),
            cpu                             = ifelse(input$cpu_flag == "CPU", TRUE, FALSE),
            to_numpy                        = FALSE,
            verbose                         = as.integer(1),
            time_flag                       = TRUE,
            n_windows_percent               = as.numeric(input$ft_window_percent),
            training_percent                = as.numeric(input$ft_training_percent),
            validation_percent              = as.numeric(input$ft_validation_percent),
            num_epochs                      = as.integer(input$ft_num_epochs),
            shot                            = TRUE,
            eval_pre                        = TRUE,
            eval_post                       = TRUE,
            lr_scheduler_flag               = FALSE,
            lr_scheduler_name               = "linear",
            lr_scheduler_num_warmup_steps   = as.integer(0),
            window_sizes                    = list(as.integer(input$wlen)),
            n_window_sizes                  = as.integer(input$ft_num_windows),
            window_sizes_offset             = as.numeric(0.05),
            windows_min_distance            = as.integer(input$ft_min_windows_distance),
            full_dataset                    = TRUE
        )
        showModal(modalDialog(
            title = "Processing...",
            "Please wait while the model is fine tuned.",
            uiOutput("dummyLoad") %>% shinycssloaders::withSpinner(
                #type = 2,
                #color = "#0275D8",
                #color.background =  "#FFFFFF"
            ),  
            easyClose = FALSE,
            footer = NULL
        ))
        # Ejecutar la operación de fine-tuning
        t_init <- Sys.time()
        result <- do.call(dvats$fine_tune_moment_, fine_tune_kwargs)
        t_end <- Sys.time()
        eval_results_pre <- result[[2]]
        eval_results_post <- result[[3]]
        t_shots <- result[[4]]
        t_shot <- result[[5]]
        t_evals <- result[[6]]
        t_eval <- result[[7]]
        diff = t_end - t_init
        diff_secs = diff
        diff_mins = diff / 60
        log_print(paste0("Fine tune: ", diff_secs, " s | approx ", diff_mins, "min" ))
        log_print(paste0("Fine tune Python single shots time: ", t_shots, "s" ))
        log_print(paste0("Fine tune Python total shot time: ", t_shot, "s" ))
        log_print(paste0("Fine tune Python single eval steps time: ", t_shots, "s" ))
        log_print(paste0("Fine tune Python total eval time: ", t_shot, "s" ))
        log_print(paste0("Fine tune Python single shots time: ", t_shots, "s" ))
        log_print(paste0("Fine tune eval results pre-tune: ", eval_results_pre, "s" ))
        log_print(paste0("Fine tune eval results post-tune: ", eval_results_post, "s" ))
        update_play_fine_tune_button()
        removeModal()
    }
})







 prj_object_cpu <- reactive({
        embs = req(embs(), input$dr_method)
        embs = embs[complete.cases(embs),]
        log_print("--> prj_object")
        log_print("--> prj_object | UMAP params")
        
        res = switch( input$dr_method,
            UMAP = dvats$get_UMAP_prjs(
                input_data  = embs, 
                cpu         = TRUE, 
                verbose     = as.integer(1),
                n_neighbors = as.integer(input$prj_n_neighbors),
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
                random_state=as.integer(input$prj_random_state),
                n_components = 2
            ),
            PCA_UMAP = dvats$get_PCA_UMAP_prjs(
                input_data  = embs, 
                cpu         = TRUE, 
                pca_kwargs  = dict(random_state= as.integer(input$prj_random_state)),
                umap_kwargs = dict(random_state= as.integer(input$prj_random_state), n_neighbors = input$prj_n_neighbors, min_dist = input$prj_min_dist)
            )
        )
      res = res %>% as.data.frame # TODO: This should be a matrix for improved efficiency
      colnames(res) = c("xcoord", "ycoord")
      on.exit({log_print(" prj_object -->"); flush.console()})
      flush.console()
      res
    })

    prj_object <- reactive({
        req(embs(), input$dr_method)
        log_print("--> prj_object")
        t_prj_0 = Sys.time()
        embs = req(embs())
        log_print(paste0("prj_object | Before complete cases embs ~", dim(embs)))
        embs = embs[complete.cases(embs),]
        #log_print(embs) #--
        #log_print(paste0("--> prj_object | UMAP params ", str(umap_params_)))
        log_print("prj_object | Before switch ")
        
        cpu_flag = ifelse(input$cpu_flag == "CPU", TRUE, FALSE)

        res = switch( input$dr_method,
            UMAP = dvats$get_UMAP_prjs(
                input_data  = embs, 
                cpu         = cpu_flag, 
                verbose     = as.integer(1),
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
            ),
            PCA_UMAP = dvats$get_PCA_UMAP_prjs(
                input_data  = embs, 
                cpu         = cpu_flag, 
                verbose     = as.integer(1),
                pca_kwargs  = dict(random_state= as.integer(input$prj_random_state)),
                umap_kwargs = dict(random_state= as.integer(input$prj_random_state), n_neighbors = input$prj_n_neighbors, min_dist = input$prj_min_dist)
            )
        )
      res = res %>% as.data.frame # TODO: This should be a matrix for improved efficiency
      colnames(res) = c("xcoord", "ycoord")
            flush.console()
      t_prj_1 = Sys.time()
      on.exit({
        log_print(
            paste0(" prj_object | cpu_flag: ",
            input$cpu_flag, " | ", input$dr_method, 
            " | Execution time: ", t_prj_1-t_prj_0 , 
            " seconds -->"
            ), TRUE, log_path(), log_header()
        ); temp_log <<- log_add(
            log_mssg            = temp_log,
            function_           = "PRJ Object",
            cpu_flag            = isolate(input$cpu_flag),
            dr_method           = isolate(input$dr_method),
            clustering_options  = isolate(input$clustering_options),
            zoom                = isolate(input$zoom_btn),
            time                =  t_prj_1-t_prj_0, 
            mssg                = paste0("Compute projections | prj ~", dim(res)) 
        ); flush.console()

    })
      res
    })

    

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
        log_print("Reactive tsdf | Make conversion -->")
        log_print("Reactive tsdf | Make conversion ")
        flush.console()
        return(unlist(result))
    }

    allow_tsdf <- reactiveVal(TRUE)

    observeEvent ( input$get_tsdf ,{
        log_print(paste0("get_tsdf changed to: ", input$get_tsdf))
        allow_tsdf( !allow_tsdf() )
        tsdf <- tsdf()
        log_print(paste0("allow_tsdf changed to: ", allow_tsdf()))
    })


    # Load and filter TimeSeries object from wandb
    tsdf <- reactive(
        {
            req(input$encoder, ts_ar())
            log_print(paste0("--> Reactive tsdf"))
            req(allow_tsdf())
            log_print("--> Reactive tsdf | allow_tsdf ")
            ts_ar = ts_ar()
            log_print(paste0("--> Reactive tsdf | ts artifact ", ts_ar()))
            flush.console()
            t_init <- Sys.time()
            # Get the full path
            path = file.path(DEFAULT_PATH_WANDB_ARTIFACTS, ts_ar$metadata$TS$hash)
            print(paste0("Reactive tsdf | Read feather ", path ))
            flush.console()
            log_print(paste0("Reactive tsdf | Read feather | Before | ", path))
            t_0 <- Sys.time()
            df <- tryCatch({ # The perfect case
                # --- Read from feather file --- #
                df <- read_feather(path, as_data_frame = TRUE, mmap = TRUE) %>% rename('timeindex' = `__index_level_0__`) 
                df
            }, error = function(e) {
                # --- Download from Weight & Biases and save the feather for the future --- #
                warning(paste0("Reactive tsdf | Read feather --> | Failed to read feather file: ", e$message))
                print(paste0("Reactive tsdf | --> Download from Weight & Biases"))
                flush.console()
                # Download the artifact and return the dataset's feather local path
                dataset_artifact_dir <- ts_ar$download()
                print(paste0("Reactive tsdf | Download from Weight & Biases | dataset artifact dir: ", dataset_artifact_dir))
                ar_path = file.path(dataset_artifact_dir, ts_ar$metadata$TS$hash)
                # Move the file to the default path
                file.copy(
                    from        = ar_path, 
                    to          = path, 
                    overwrite   = TRUE, 
                    recursive   = FALSE, 
                    copy.mode   = TRUE
                )
                # Read from feather
                df <- read_feather(
                    path, 
                    as_data_frame = TRUE, 
                    mmap = TRUE
                ) %>% rename('timeindex' = `__index_level_0__`)
                df_read_option <- "Download from W&B and read from feather"
                df
            }, finally = {
                t_1 = Sys.time()
                log_print(paste0("Reactive tsdf | Read feather | After | ", path))
                log_print(paste0("Reactive tsdf | Read feather | Load time: ", t_1 - t_0, " seconds | N elements: ", nrow(df)), TRUE, log_path(), log_header())
           
                temp_log <<- log_add(
                    log_mssg            = temp_log, 
                    function_           = "TSDF | Load dataset | Read feather",
                    cpu_flag            = isolate(input$cpu_flag),
                    dr_method           = isolate(input$dr_method),
                    clustering_options  = isolate(input$clustering_options),
                    zoom                = isolate(input$zoom_btn),
                    time                = t_1-t_0, 
                    mssg                = "Read feather"
                )
                flush.console()
                tsdf_ready(TRUE)
                log_print(paste0("Reactive tsdf | Execution time: ", t_1 - t_0, " seconds | df ~ ", dim(df)));flush.console()
                df
            })
            df
        })
    
    # Auxiliary object for the interaction ts->projections
    tsidxs_per_embedding_idx <- reactive({
        #window_indices = get_window_indices(embedding_indices, input$wlen, input$stride)
        req(input$wlen != 0, input$stride != 0)
        ts_indices <- get_window_indices(1:nrow(projections()), w = input$wlen, s = input$stride)
        ts_indices
    })
    
    # Filter the embedding points and calculate/show the clusters if conditions are met.
    projections <- reactive({
        log_print("--> Projections")
        req(input$dr_method)
        #prjs <- req(prj_object()) %>% slice(input$points_emb[[1]]:input$points_emb[[2]])
        log_print("Projections | before prjs")
        prjs <- req(prj_object())
        req(input$dataset, input$encoder, input$wlen, input$stride)
        log_print("Projections | before switch")
        log_print("Calculate clusters | before")
        tcl_0 = Sys.time()
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
                log_print(paste0("Projections | Score ", score))
                #if (score <= 0) {
                #    log_print(paste0("Projections | Repeat projections with CPU because of low quality clusters | score ", score))
                #    prjs <- prj_object_cpu()
                #    clusters = hdbscan$HDBSCAN(
                #        min_cluster_size = as.integer(clusters_config$min_cluster_size_hdbscan),
                #        min_samples = as.integer(clusters_config$min_samples_hdbscan),
                #        cluster_selection_epsilon = clusters_config$cluster_selection_epsilon_hdbscan,
                #        metric = clusters_config$metric_hdbscan
                #    )$fit(prjs)
#score = 0
 #                   unique_labels <- unique(clusters$labels_)
 #                   total_unique_labels <- length(unique_labels)
  #                  if(total_unique_labels > 1){
   #                 score = dvats$cluster_score(prjs, clusters$labels_, TRUE)
    #                }
                #    log_print(paste0("Projections | Repeat projections with CPU because of low quality clusters | score ", score))
                #}
                prjs$cluster <- clusters$labels_
tcl_1 = Sys.time()
                log_print(paste0("Compute clusters | Execution time ", tcl_1 - tcl_0), TRUE, log_path(), log_header())
                temp_log <<- log_add(
                    log_mssg                = temp_log, 
                    function_               = "Projections | Hdbscan",
                    cpu_flag                = isolate(input$cpu_flag),
                    dr_method               = input$dr_method,
                    clustering_options      = input$clustering_options,
                    zoom                    = input$zoom,
                    time                    = tcl_1-tcl_0, 
                    mssg                    = "Compute clusters"
                )
                prjs$cluster
             })
        
        on.exit({log_print("Projections -->"); flush.console()})
      prjs
    })
    
    # Update the colour palette for the clusters
    update_palette <- reactive({
        prjs <- req(projections())
        if ("cluster" %in% names(prjs)) {
            unique_labels <- unique(prjs$cluster)
            log_print(unique_labels)
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
    
    

    start_date <- reactive({
        sd <- tsdf()$timeindex[1]
        on.exit({print(paste0("start_date --> ", sd)); flush.console()})
        sd
    })

    end_date <- reactive({
        end_date_id = as.integer(100000)
        end_date_id = min(end_date_id, nrow(tsdf()))
        ed <- tsdf()$timeindex[end_date_id]
        on.exit({print(paste0("end_date --> ", ed)); flush.console()})
        ed
    })
    ts_plot_base <- reactive({
        log_print("--> ts_plot_base")
        on.exit({log_print("ts_plot_base -->"); flush.console()})
        start_date =isolate(start_date())
        end_date = isolate(end_date())
        log_print(paste0("ts_plot_base | start_date: ", start_date, " end_date: ", end_date))
        t_ts_plot_0 <- Sys.time()
        #tsdf_ <- isolate(tsdf()) %>% select(isolate(ts_variables$selected), - "timeindex")
        tsdf_ <- tsdf() %>% select(ts_variables$selected, - "timeindex")
        tsdf_xts <- xts(tsdf_, order.by = tsdf()$timeindex)
        t_ts_plot_1 <- Sys.time()
        log_print(paste0("ts_plot_base | tsdf_xts time", t_ts_plot_1-t_ts_plot_0)) 
        temp_log <<- log_add(
          log_mssg            = temp_log, 
          function_           = "Reactive X | SWV",
          cpu_flag            = isolate(input$cpu_flag),
          dr_method           = isolate(input$dr_method),
          clustering_options  = isolate(input$clustering_options),
          zoom                = isolate(input$zoom_btn),
          time                = t_ts_plot_1-t_ts_plot_0,
          mssg                = "tsdf_xts"
        )
        log_print(head(tsdf_xts))
        log_print(tail(tsdf_xts))
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

    embedding_ids <- reactive({
        log_print("--> embedding idx")
        on.exit({log_print("embedding idx -->");})
        bp = brushedPoints(prj_object(), input$projections_brush, allRows = TRUE) #%>% debounce(miliseconds) #Wait 1 seconds: 1000
        bp %>% rownames_to_column("index") %>% dplyr::filter(selected_ == TRUE) %>% pull(index) %>% as.integer
    })

    
    
    
    filtered_window_indices <- reactive({
        req(length(embedding_ids() > 0))
        #embedding_indices <- embedding_ids()
        #ts_indices <- tsidxs_per_embedding_idx()
        #unique(unlist(ts_indices[embedding_indices]))

        embedding_indices <- embedding_ids()
        
        window_indices <- get_window_indices_(embedding_indices, input$wlen, input$stride)
        window_indices
    })

    window_list <- reactive({
        # Get the indices of the windows related to the selected projection points
        log_print("--> window_list")
        on.exit(log_print("window_list -->"))
        # Get the window indices
        window_indices <- filtered_window_indices()
        # Put all the indices in one list and remove duplicates
        unlist_window_indices = filtered_window_indices()
        # Calculate a vector of differences to detect idx where a new window should be created 
        diff_vector <- diff(unlist_window_indices,1)
        #log_print(paste0("|| window list || diff ", diff_vector))
        # Take indexes where the difference is greater than one (that represent a change of window)
        idx_window_limits <- which(diff_vector!=1)
        log_print(paste0("|| window_list || idx_window_limits", idx_window_limits))
        # Include the first and last index to have a whole set of indexes.
        idx_window_limits <- c(1, idx_window_limits, length(unlist_window_indices))
        
        # Create a reduced window lists
        reduced_window_list <-  vector(mode = "list", length = length(idx_window_limits)-1)
        # Populate the first element of the list with the idx of the first window.
        reduced_window_list[[1]] = c(            
            unlist_window_indices[idx_window_limits[1]+1],
            unlist_window_indices[idx_window_limits[2]]
        ) 
        # Populate the rest of the list
        if (length(idx_window_limits) > 2) {
            for (i in 2:(length(idx_window_limits)-1)){
                reduced_window_list[[i]]<- c(
                    unlist_window_indices[idx_window_limits[i]+1],
                    unlist_window_indices[idx_window_limits[i+1]]
               )
            }
        }
        reduced_window_list
    })
    

    # Generate timeseries data for dygraph dygraph
    ts_plot <- reactive({
        log_print("--> ts_plot | Before req 1")
        t_tsp_0 = Sys.time()
        on.exit({log_print("ts_plot -->"); flush.console()})
        print(paste0("ts_plot | Before req 2 | tsdf_ready ", tsdf_ready()))
        req(tsdf(), ts_variables, input$wlen != 0, input$stride, tsdf_ready())

        ts_plt = ts_plot_base() 

        log_print("ts_plot | bp")
        #miliseconds <-  ifelse(nrow(tsdf()) > 1000000, 2000, 1000)
        
        #if (!is.data.frame(bp)) {bp = bp_}
        log_print("ts_plot | embedings idxs ")
        embedding_idxs = embedding_ids()
        # Calculate windows if conditions are met (if embedding_idxs is !=0, that means at least 1 point is selected)
        log_print("ts_plot | Before if")
        if ((length(embedding_idxs)!=0) & isTRUE(input$plot_windows)) {
            reduced_window_list = req(window_list())
            #log_print(paste0("ts_plot | Selected projections ", reduced_window_list[1]), TRUE, log_path(), log_header())
            start_indices = min(sapply(reduced_window_list, function(x) x[1]))
            end_indices = max(sapply(reduced_window_list, function(x) x[2]))

            log_print(paste0("|| ts_plot || Reduced ", reduced_window_list))
            log_print(paste0("|| ts_plot || sd_id ", start_indices))
            log_print(paste0("|| ts_plot || ed_id ", end_indices))

            if (!is.na(start_indices) && !is.na(end_indices)) {
                view_size = end_indices-start_indices+1
                max_size = 10000

                start_date = tsdf()$timeindex[start_indices]
                end_date = tsdf()$timeindex[end_indices]
                start_date

                log_print(paste0("ts_plot | reduced_window_list (", start_date, end_date, ")", "view size ", view_size, "max size ", max_size))
            
                if (view_size > max_size) {
                    end_date = tsdf()$timeindex[start_indices + max_size - 1]
                    #range_color = "#FF0000" # Red
                } 
            
                range_color = "#CCEBD6" # Original
            

                # # Plot the windows
                count = 0
                for(ts_idxs in reduced_window_list) {
                    count = count + 1
                    start_event_date = tsdf()$timeindex[head(ts_idxs, 1)]
                    end_event_date = tsdf()$timeindex[tail(ts_idxs, 1)]
                    ts_plt <- ts_plt %>% dyShading(
                        from = start_event_date,
                        to = end_event_date,
                        color = range_color
                    ) 
                ts_plt <- ts_plt %>% dyRangeSelector(c(start_date, end_date))
                }   
            
                ts_plt <- ts_plt
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
            } else {
                log_print(paste0("-- Error obtaining selected projection points start_id ", start_indices, "| end_id ", end_indices))
            }
        }
        t_tsp_1 = Sys.time()
        log_print(paste0("ts plot | Execution time: ", t_tsp_1 - t_tsp_0))
        ts_plt
    })
    

    #############
    #  OUTPUTS  #
    #############

    color_palete_window_plot <- colorRampPalette(
        colors = c("blue", "green"),
        space = "Lab" # Option used when colors do not represent a quantitative scale
    )
    output$windows_plot <- renderPlot({
        req(length(embedding_ids()) > 0)
        reduced_window_list = req(window_list())

        # Convertir a fechas POSIXct
        reduced_window_df <- do.call(rbind, lapply(reduced_window_list, function(x) {
            data.frame(
                start = as.POSIXct(tsdf()$timeindex[x[1]], origin = "1970-01-01"),
                end = as.POSIXct(tsdf()$timeindex[x[2]], origin = "1970-01-01")
            )
        }))

        # Establecer límites basados en los datos
        first_date = min(reduced_window_df$start)
        last_date = max(reduced_window_df$end)
    
        left = as.POSIXct(tsdf()$timeindex[1],  origin = "1970-01-01")
        right = as.POSIXct(tsdf()$timeindex[nrow(tsdf())], origin = "1970-01-01")

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
            start <- format(as.POSIXct(tsdf()$timeindex[window[1]], origin = "1970-01-01"), "%b %d")
            end <- format(as.POSIXct(tsdf()$timeindex[window[2]], origin = "1970-01-01"), "%b %d")
            color <- ifelse(i %% 2 == 0, "green", "blue")
            HTML(paste0("<div style='color: ", color, "'>Window ", i, ": ", start, " - ", end, "</div>"))
        })

        # Devuelve todos los elementos de texto como una lista de HTML
        do.call(tagList, window_info)
    })
    
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
        on.exit({log_print("Encoder artiffact -->"); flush.console()})
        log_print(paste0("--> Encoder artiffact", selected_encoder_name))
        selected_encoder <- encs_l[[selected_encoder_name]]
        encoder_metadata <- req(selected_encoder$metadata)
        log_print(paste0("Encoder artiffact | encoder metadata ", selected_encoder_name))
        encoder_metadata %>%enframe()
            })
    
    # Generate time series info table
    output$ts_ar_info = renderDataTable({
        log_print("--> ts_ar_info")
        on.exit(log_print("ts_ar_info -->"))
        print(ts_ar_config())
        ts_ar_config() %>% enframe()
    })
       
    # Generate projections plot
    output$projections_plot <- renderPlot({
        req( 
            input$dataset,
            input$encoder,
            input$wlen != 0,
            input$stride != 0,
            tsdf_ready()
        )
        log_print("--> Projections_plot")
        t_pp_0 <- Sys.time()
        prjs_ <- req(projections())
         
        log_print("projections_plot | Prepare column highlights")
        # Prepare the column highlight to color data
        if (!is.null(input$ts_plot_dygraph_click)) {
            log_print("Selected ts time points" , TRUE, log_path(), log_header())
            selected_ts_idx <- which(ts_plot()$x$data[[1]] == input$ts_plot_dygraph_click$x_closest_point)
            ##### ---- AQUI --- #### #indices_per_embedding <- tsidxs_per_embedding_idx()
            indices_per_embedding <- get_window_indices(embedding_ids(), input$wlen, input$stride)
            #log_print(paste0("TS indices per embedding idx: ", indices_per_embedding))
            projections_idxs <- indices_per_embedding %>% map_lgl(~ selected_ts_idx %in% .)
            log_print(paste0("prjs_ ~ ", indices_per_embedding))
            prjs_$highlight <- projections_idxs
            
            

        } else {
            prjs_$highlight = FALSE
        }
        # Prepare the column highlight to color data. If input$generate_cluster has not been clicked
        # the column cluster will not exist in the dataframe, so we create with the value FALSE
        if(!("cluster" %in% names(prjs_)))
            prjs_$cluster = FALSE
        log_print(paste0("projections_plot | GoGo Plot!", nrow(prjs_)))
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
            ggsave(filename = set_prjs_plot_name(), plot = plt, path = "../data/plots/")
        })
        t_pp_1 = Sys.time()
        log_print(paste0("projections_plot | Projections Plot time: ", t_pp_1-t_pp_0), TRUE, log_path(), log_header())
        temp_log <<- log_add(
            log_mssg                = temp_log, 
            function_               = "Projections Plot",
            cpu_flag                = isolate(input$cpu_flag),
            dr_method               = input$dr_method,
            clustering_options      = input$clustering_options,
            zoom                    = input$zoom_btn,
            time                    = t_pp_1-t_pp_0, 
            mssg                    = paste0("R execution time | Ts selected point", input$ts_plot_dygraph_click)
        )
        plt
    })
    
    
    # Render projections plot
    output$projections_plot_ui <- renderUI(
        {
            plotOutput(
                "projections_plot", 
                click = "projections_click",
                brush = "projections_brush",
                height = input$embedding_plot_height
            ) %>% withSpinner()
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
                tsdf(), 
                input$encoder,
                input$wlen != 0, 
                input$stride != 0
            )
            log_print("**** ts_plot dygraph ****")
            tspd_0 = Sys.time()
            ts_plot <- req(ts_plot())
            #ts_plot %>% dyAxis("x", axisLabelFormatter = format_time_with_index) %>% JS(js_plot_with_id)
            ts_plot %>% dyCallbacks(drawCallback = JS(js_plot_with_id))
            tspd_1 = Sys.time()
            log_print(
                paste0(
                    mssg = "ts_plot dygraph | Execution_time: ", tspd_1 - tspd_0), 
                    file_flag = TRUE, 
                    file_path = log_path(), 
                    log_header = log_header(), 
                    debug_level = debug_level, 
                    debug_group ='main'
                )
            #temp_log <<- log_add(
            #    log_mssg                = temp_log, 
            #    function_               = "TS Plot Dygraph",
            #    cpu_flag                = isolate(input$cpu_flag),
            #    dr_method               = isolate(input$dr_method),
            #    clustering_options      = isolate(input$clustering_options),
            #    zoom                    = isolate(input$zoom),
            #    mssg                    = paste0("R execution time | Selected prj points: ", isolate(embedding_ids())),
            #    time                    = tspd_1-tspd_0
            #)
            ts_plot
        }   
    )


    ########### Saving graphs in local
    
    

    
    
    ###################################
    ########## JSCript Logs ###########
    ###################################
    output$logsOutput <- renderText({
        logMessages()
    })

    observe({
        req(input$renderTimes)
        renderTimes <- fromJSON(input$renderTimes)
        for (plot_id in names(renderTimes)) {
            last_time = as.double(renderTimes[[plot_id]][length(renderTimes[[plot_id]])])
            mssg <- paste(plot_id, last_time, sep=", ")
            log_print(paste0("| JS PLOT RENDER | ", mssg), TRUE, log_path(), log_header())
            #temp_log <<- log_add(
            #    log_mssg                = temp_log,
            #    function_               = paste0("JS Plot Render ", plot_id),
            #    cpu_flag                = isolate(input$cpu_flag),
            #    dr_method               = isolate(input$dr_method),
            #    clustering_options      = isolate(input$clustering_options),
            #    zoom                    = isolate(input$zoom_btn),
            #    time                    = last_time,
            #    mssg                    = paste0(plot_id, "renderization time (milisecs)")
            #)
            temp_log <<- log_add(
                log_mssg                = temp_log,
                function_               = paste0("JS Plot Render ", plot_id),
                cpu_flag                = isolate(input$cpu_flag),
                dr_method               = isolate(input$dr_method),
                clustering_options      = isolate(input$clustering_options),
                zoom                    = isolate(input$zoom_btn),
                time                    = last_time/1000,   
                mssg                    = paste0(plot_id, " renderization time (secs)")
            )
        } 
    })
    
    update_trigger <- reactiveVal(FALSE)
    observeEvent(input$update_logs, {
        update_trigger = !update_trigger
    })

    timestamp_min_max <- reactive({
        data <- log_df()  # Obtén tus datos aquí
        if (nrow(data) == 0){
            min_max = c("Loading...","Loading...")
        } else {
            min_max <- range(data$timestamp, na.rm = TRUE)
            if (min_max[1] == min_max[2]) {min_max[2] = min_max[1]+10}
        }
        return(min_max)
    })

    output$log_output <- renderDataTable({
        trigger <- update_trigger()
        logs = log_df()
        if (nrow(logs) == 0) {
            return(dataTableOutput("No available log."))
        } 
        logs 
    })

    output$download_data <- downloadHandler(
        filename = function() {
            paste("logs-", Sys.Date(), execution_id, ".csv", sep="")
        },
        content = function(file) {
            write.csv(log_df(), file)
        }
    )
    
    
    mplot_start_computation <- reactiveVal(FALSE)

    observeEvent(input$tabs, {
      if (input$tabs == "MPlot") {
            mplot_start_computation(TRUE)
            log_print(
                paste0(
                    "mplot_start_computation |", 
                    mplot_start_computation(),
                     " | ", 
                    input$tabs
                )
            )
            mplot_tabServer(
                "mplot_tab1", 
                tsdf                = tsdf, 
                mplot_compute_allow = mplot_compute_allow,
                input_caller        = input,
                output_caller       = output,
                session_caller      = session,
                start_computation   = mplot_start_computation
            )   
      } else {
            mplot_start_computation(FALSE)
            log_print(
                paste0(
                    "mplot_start_computation |", 
                    mplot_start_computation(),
                     " | ", 
                    input$tabs
                )
            )
      }
    })

    
    load_datasetServer("load_dataset1")

    output$ft_batch_size_value <- renderText({
        paste("Batch Size value:", input$ft_batch_size)
    })
  
    output$ft_window_percent_value <- renderText({
        paste("Window Percent value:", input$ft_window_percent)
    })


})

