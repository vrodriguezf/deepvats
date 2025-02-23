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
source("./lib/server/logs.R", encoding = "utf-8")
source("./lib/server/plots.R", encoding = "utf-8")
source("./lib/server/server.R", encoding = "utf-8")
source("./modules/parameters.R", encoding = "utf-8")
source("./modules/mplots.R", encoding = "utf-8")
source("./lib/server/logs_config.R", encoding = "utf-8")

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
    ts_variables <- reactiveValues(
        original        = NULL,
        preprocessed    = NULL,
        complete        = NULL,
        selected        = NULL
    )
    
    ## -- Dataset
    # Dataset 
    ts_ar                   <- reactiveVal(NULL)
    # DataFrame
    tsdf                    <- reactiveVal(NULL)
    tsdf_preprocessed       <- reactiveVal(NULL)
    tsdf_concatenated       <- reactiveVal(NULL)
    tsdf_preprocessed_params<- reactiveVal(NULL)
    tsdf_path               <- reactiveVal(NULL)
    enc_input_path          <- reactiveVal(NULL)
    # Enc input
    X                       <- reactiveVal(NULL)
    # Embeddings
    embs                    <- reactiveVal(NULL)
    embs_complete_cases     <- reactiveVal(NULL)
    prjs                    <- reactiveVal(NULL)
    ## -- Flags
    # DataFrame
    allow_tsdf              <- reactiveVal(FALSE)
    get_tsdf_prev           <- reactiveVal(NULL)
    tsdf_ready              <- reactiveVal(FALSE)
    tsdf_ready_preprocessed <- reactiveVal(TRUE)
    # CPU
    force_cpu   <- reactiveVal(FALSE)
    cpu_flag    <- reactiveVal(FALSE)  
    # Variates
    ts_vars_selected_mod    <- reactiveVal(FALSE)
    # Encoder
    enc                     <- reactiveVal(NULL)
    # Embeddings
    cached_embeddings       <- reactiveVal(NULL)
    embs_params             <- reactiveVal(
        list (
            dataset     = NULL,
            encoder     = NULL,
            wlen        = NULL,
            stride      = NULL,
            fine_tune   = NULL,
            processed   = NULL,
            path        = NULL
        )
    )
    # Preprocess
    preprocess_play_flag    <- reactiveVal(FALSE)
    preprocess_dataset_prev <- reactiveVal(FALSE)
    proposed_wlen           <- reactiveVal(NULL)
    proposed_section_sizes  <- reactiveVal(NULL)
    # Logs
    update_trigger          <- reactiveVal(FALSE)
    temp_log                <- data.frame(
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
    # MPlot
    mplot_start_computation <- reactiveVal(FALSE)
    mplot_compute_allow     <- reactiveVal(TRUE)
    # Application reactiveness
    play                    <- reactiveVal(FALSE)
    play_fine_tune          <- reactiveVal(FALSE)
    enc_input_ready         <- reactiveVal(FALSE)
    allow_update_len        <- reactiveVal(TRUE)
    allow_update_embs       <- reactiveVal(FALSE)
    play_prjs               <- reactiveVal(FALSE)
    # Application options
    wlen_min                <- reactiveVal(0)
    wlen_max                <- reactiveVal(0)
    sections_count          <- reactiveVal(0)
    sections_size           <- reactiveVal(0)
    random_state_min        <- reactiveVal(0)
    random_state_max        <- reactiveVal(0)
    pca_random_state_min    <- reactiveVal(0)
    pca_random_state_max    <- reactiveVal(0)
    tsne_random_state_min   <- reactiveVal(0)
    tsne_random_state_max   <- reactiveVal(0)
    # ts_plot    
    #################################
    #  OBSERVERS & OBSERVERS EVENTS #
    #################################

    update_play_pause_button <- reactive({
        log_print("--> Update play_pause_button", debug_group='debug')
        on.exit({log_print(paste0("Update play_pause_button || ",play()," -->"), debug_group = 'debug')})
        if (play()) {
            updateActionButton(session, "play_pause", label = "Pause", icon = shiny::icon("pause"))
            allow_tsdf(TRUE)
            tsdf_ready(FALSE)
            tsdf_ready_preprocessed(TRUE)
            log_print("Update play_pause_button | --> compute tsdf", debug_group = "debug")
            req(tsdf_comp())
            log_print("Update play_pause_button | compute tsdf -->", debug_group = "debug")
        } else {
            updateActionButton(session, "play_pause", label = "Start with the dataset!", icon = shiny::icon("play"))
            allow_tsdf(FALSE)
        }
    })

    update_play_pause_button_preprocessed <- reactive({
        log_print("--> Update play_pause_button_preprocessed", debug_group='debug')
        on.exit({log_print(paste0("Update play_pause_button_preprocessed || ",play()," -->"), debug_group = 'debug')})
        if (play()) {
            updateActionButton(session, "play_pause", label = "Pause", icon = shiny::icon("pause"))
            allow_tsdf(FALSE)
            tsdf_ready_preprocessed(FALSE)
            print(paste0("TSDF READY A FALSE 2", tsdf_ready_preprocessed())) #quitar
            log_print("Update play_pause_button_preprocessed | --> compute tsdf", debug_group = "debug")
            #allow_update_embs(FALSE)
            #enable_disable_embs()
            log_print("Update play_pause_button_preprocessed | compute tsdf -->", debug_group = "debug")
        } else {
            updateActionButton(session, "play_pause", label = "Start with the dataset!", icon = shiny::icon("play"))
            allow_tsdf(FALSE)
        }
    })

    update_play_fine_tune_button <- function() {
        log_print(paste0("--> Updating play_fine_tune ", play_fine_tune()), debug_group = 'button')
        play_fine_tune(!play_fine_tune())
        if (play_fine_tune()) {
            updateActionButton(session, "fine_tune_play", label = "Pause", icon = shiny::icon("pause"))
        } else {
            updateActionButton(session, "fine_tune_play", label = "Run!", icon = shiny::icon("play"))
        }
        log_print(paste0(" Updating play_fine_tune --> ", play_fine_tune()), debug_group = 'button')
    }
    observeEvent(input$fine_tune_play, {
        update_play_fine_tune_button()
    })

    observeEvent(input$play_pause, {
        log_print("--> observeEvent input$play_pause", debug_group = 'button')
        on.exit({log_print("observeEvent input$play_pause | Run -->", debug_group='button')})
        play(!play())
        update_play_pause_button()
    })

    observeEvent(input$cuda, {
        log_print("--> Cleanning cuda objects", debug_group = 'button')
        torch$cuda$empty_cache()
        log_print("Cleanning cuda objects -->", debug_group = 'button')
    })

    observeEvent(
        #req(exists("encs_l")), 
        req(exists("data_l")),
        {
            freezeReactiveValue(input, "dataset")
            log_print("observeEvent encoders list enc_l | update dataset list | after freeze", debug_group='button')
            updateSelectizeInput(
                session = session,
                inputId = "dataset",
                #choices = encs_l %>% 
                #map(~.$metadata$train_artifact) %>% 
                #set_names()
                choices = sapply(data_l, function(art) art$name)
            )
            on.exit({log_print("observeEvent encoders list encs_l | update dataset list -->", debug_group='button'); flush.console()})
        }, 
        label = "input_dataset"
    )

    select_datasetServer(encs_l, mplot_compute_allow, input, output, session)
    # Get encoder artifact
    
    enc_ar <- eventReactive(
        input$encoder, 
        {
            log_print(paste0("eventReactive enc_ar | Enc. Artifact: ", input$encoder), debug_group = 'react')
            result <- tryCatch({
                api$artifact(input$encoder, type = 'learner')
            }, error = function(e){
                log_print(paste0("eventReactive enc_ar | Error: ", e$message), debug_group = 'error')
                NULL
            })
            on.exit({
                log_print(
                    "envent reactive enc_ar -->", 
                    debug_group = 'react'
                ); 
                flush.console()
            })
            result
        }
    )
    
    observeEvent(
        input$encoder,
        {
            log_print(mssg = "--> observeEvent input_encoder", debug_group = 'main')
            
            freezeReactiveValue(input, "wlen")
            
            log_print("observeEvent input_encoder | update wlen | Before enc_ar", debug_group = 'debug')
            
            enc_ar = enc_ar()
            
            log_print(paste0("observeEvent input_encoder | update wlen | enc_ar: ", enc_ar, "| Set wlen slider values"),  debug_group = 'debug')
    
            if (is.null(enc_ar$metadata$mvp_ws)) {
                log_print("observeEvent input_encoder | update wlen | Set wlen slider values from w | ",  debug_group = 'debug')
                enc_ar$metadata$mvp_ws = c(enc_ar$metadata$w, enc_ar$metadata$w)
            }
            
            log_print(paste0("observeEvent input_encoder | update wlen | enc_ar$metadata$mvp_ws ", enc_ar$metadata$mvp_ws ),  debug_group = 'debug')
            
            wmin <- enc_ar$metadata$mvp_ws[1]
            wmax <- enc_ar$metadata$mvp_ws[2]
            wlen <- enc_ar$metadata$w
            
            log_print(
                paste0(
                    "observeEvent input_encoder | update wlen | Update slider input ",
                    "ws: (", wmin, ", ", wmax, ")",
                    " |  wlen: ", wlen 
                ),  debug_group = 'button')
            
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
                file_flag = FALSE, debug_group = 'button'
            ); flush.console()
            })
        }
    )
  
    propose_wlen <- function(data, indexname, ncol = 1){
        log_print("--> propose sizes ", debug_group = 'debug')
        data    <- data %>% select(-all_of(indexname))
        log_print(paste0("propose sizes || ", paste(colnames(data), collapse = ', ')), debug_group = 'debug')
        #index   <- as.integer(seq_len(nrow(data)))
        if (ncol(data) > 1){ data <- data[[min(length(data), ncol)]]}
        sizes <- utils$find_dominant_window_sizes_list(
                X               = np$array(data[[1]]),
                nsizes          = 5,
                offset          = 0.05,
                verbose         = as.integer(0),
                min_distance    = 5
            )
        proposed_wlen( sizes )
        log_print("propose sizes --> ", debug_group = 'debug')
        return(sizes)
    }

    propose_section_sizes <- function(wlens, data, factor_range = seq(1, 5, by = 1)) {
        log_print("--> propose section sizes", debug_group = 'debug')
        max_rows <- nrow(data)
    
        sizes <- sort(unique(as.integer(outer(wlens, factor_range, `*`))))

        sizes <- sizes[sizes > 0 & sizes <= max_rows]

        log_print(paste0("Proposed section sizes: ", paste(sizes, collapse = ", ")), debug_group = 'debug')
        proposed_section_sizes(sizes)
        return(sizes)
    }

    observeEvent(tsdf_ready(), {
        req(tsdf_ready())
        log_print("--> update_preprocess_sliders", debug_group = 'react')
        log_print("update_preprocess_sliders -->", debug_group = 'react')
        
        max_rows <- nrow(tsdf())
        if (is.null(tsdf_preprocessed()) || ! input$preprocess_dataset){
            wlens <- propose_wlen(tsdf(), 'timeindex')
            sizes <- propose_section_sizes(wlens, tsdf())
        } else {
            wlens <- propose_wlen(tsdf_preprocessed(),'timeindex_preprocessed')
            sizes <- propose_section_sizes(wlens, tsdf_preprocessed())
        }

        updateSliderInput(
            session, "so_range_normalization_sections", 
            min = 0,max = max_rows,value = 0
        )
        updateSliderInput(
            session, "so_range_normalization_sections_size", 
            min = 0,max = max_rows,value = sizes[[1]]
        )
        updateSliderInput(
            session, "ss_range_normalization_sections", 
            min = 0,max = max_rows,value = 0
        )
        updateSliderInput(
            session, "ss_range_normalization_sections_size", 
            min = 0,max = max_rows,value = sizes[[1]]
        )
    })
    

    observe({
        req(input$so_text_rns, tsdf_ready())  # Asegúrate de que tsdf() no sea NULL
        log_print("--> observe so_sections_count", debug_group = 'react')
        on.exit({log_print("observe so_sections_count -->", debug_group = 'react')})
        text <- as.integer(input$so_text_rns)  # Convierte el input a entero
        if (!is.na(text) && text > 0 && text <= nrow(tsdf())) {  # Verifica que el valor sea válido
            updateSliderInput(session, "so_range_normalization_sections", value = text)
        }
        sections_count(text)
    })
    observe({
        req(input$so_text_rnsz, tsdf_ready())  
        log_print("--> observe so_sections_size", debug_group = 'react')
        on.exit({log_print("observe so_sections_size -->", debug_group = 'react')})
        text <- as.integer(input$so_text_rnsz)
        if (!is.na(text) && text > 0 && text <= nrow(tsdf())) { 
            updateSliderInput(session, "so_range_normalization_sections_size", value = text)
        }
        sections_size(text)
    })
    observe({
        req(tsdf_ready(), input$ss_text_rns)  
        log_print("--> observe ss_text_rns", debug_group = 'react')
        on.exit({log_print("observe ss_text_rns -->", debug_group = 'react')})
        text <- as.integer(input$ss_text_rns) 
        if (!is.na(text) && text > 0 && text <= nrow(tsdf())) { 
            updateSliderInput(session, "ss_range_normalization_sections", value = text)
        }
        sections_count(text)
    })
    observe({
        req(tsdf_ready(), input$ss_text_rnsz)  
        log_print("--> observe ss_text_rnsz", debug_group = 'react')
        on.exit({log_print("observe ss_text_rnsz-->", debug_group = 'react')})
        text <- as.integer(input$ss_text_rnsz)
        if (!is.na(text) && text > 0 && text <= nrow(tsdf())) {
            updateSliderInput(session, "ss_range_normalization_sections_size", value = text)
        }
        sections_size(text)
    })

     observe({
        req(input$so_range_normalization_sections, tsdf_ready())  # Asegúrate de que tsdf() no sea NULL
        log_print("--> observe so_range_normalization_sections", debug_group = 'react')
        on.exit({log_print("observe so_range_normalization_sections -->", debug_group = 'react')})
        text <- as.integer(input$so_range_normalization_sections)  # Convierte el input a entero
        if (!is.na(text) && text > 0 && text <= nrow(tsdf())) {  # Verifica que el valor sea válido
            updateSliderInput(session, "so_range_normalization_sections", value = text)
        }
        sections_count(text)
    })
    observe({
        req(input$so_range_normalization_sections_size, tsdf_ready())  
        log_print("--> observe so_range_normalization_sections_size", debug_group = 'react')
        on.exit({log_print("observe so_range_normalization_sections_size -->", debug_group = 'react')})
        text <- as.integer(input$so_range_normalization_sections_size)
        if (!is.na(text) && text > 0 && text <= nrow(tsdf())) { 
            updateSliderInput(session, "so_range_normalization_sections_size", value = text)
        }
        sections_size(text)
    })
    observe({
        req(tsdf_ready(), input$ss_range_normalization_sections)  
        log_print("--> observe ss_range_normalization_sections", debug_group = 'react')
        on.exit({log_print("observe ss_range_normalization_sections -->", debug_group = 'react')})
        text <- as.integer(input$ss_range_normalization_sections) 
        if (!is.na(text) && text > 0 && text <= nrow(tsdf())) { 
            updateSliderInput(session, "ss_range_normalization_sections", value = text)
        }
        sections_count(text)
    })
    observe({
        req(tsdf_ready(), input$ss_range_normalization_sections_size)  
        log_print("--> observe ss_range_normalization_sections_size", debug_group = 'react')
        on.exit({log_print("observe ss_range_normalization_sections_size -->", debug_group = 'react')})
        text <- as.integer(input$ss_range_normalization_sections_size)
        if (!is.na(text) && text > 0 && text <= nrow(tsdf())) {
            updateSliderInput(session, "ss_range_normalization_sections_size", value = text)
        }
        sections_size(text)
    })

    ############ WLEN TEXT ############
    observe({
        req(input$wlen_text > 0)
        if (input$wlen != input$wlen_text) {
            # Si se ingresa un valor en wlen_text menor que el mínimo o mayor que el máximo del slider, ajustamos el slider
            if (input$wlen_text < input$wlen || input$wlen_text > input$wlen) {
                updateSliderInput(session, "wlen", 
                    min = min(input$wlen_text, wlen_min()), 
                    max = max(input$wlen_text, wlen_max()), 
                    value = input$wlen_text)
                }
        }
        allow_update_len(FALSE)
        })

        observe({
            req(input$wlen_text > 0)
            allow_update_len(TRUE)
        })

    observe({
        req(input$prj_random_state_text > 0)
        if (input$prj_random_state_text != input$prj_random_state_text) {
            prjs_random_state_min(min(input$prjs_random_state, prjs_random_state_min()))
            prjs_random_state_max(max(input$prjs_random_state_text, prjs_random_state_max()))
            updateSliderInput(session, "prjs_random_state", 
                min = prjs_random_state_min(), 
                max = prjs_random_state_max(), 
                value = input$prjs_random_state_text
            )
        }
    })

    observe({
        req(input$pca_random_state_text > 0)
        if (input$pca_random_state != input$pca_random_state_text) {
            pca_random_state_min(min(input$pca_random_state, pca_random_state_min()))
            pca_random_state_max(max(input$pca_random_state_text, pca_random_state_max()))
            updateSliderInput(session, "prjs_random_state", 
                min = pca_random_state_min(), 
                max = pca_random_state_max(), 
                value = input$pca_random_state_text
                )
        }
    })

    observe({
        req(input$tsne_random_state_text > 0)
        if (input$tsne_random_state != input$tsne_random_state_text) {
            tsne_random_state_min(min(input$tsne_random_state, tsne_random_state_min()))
            tsne_random_state_max(max(input$tsne_random_state_text, tsne_random_state_max()))
            updateSliderInput(session, "prjs_random_state", 
                min = tsne_random_state_min(), 
                max = tsne_random_state_max(), 
                value = input$tsne_random_state_text
                )
        }
    })
   
    ####### --- wlen text ---  ########


    observeEvent(input$restore_wlen_stride, {
        enc_ar = enc_ar()
         log_print(paste0("observeEvent restore wlen stride | update wlen | enc_ar$metadata$mvp_ws ", enc_ar$metadata$mvp_ws ),  debug_group = 'generic')
            
            wlen_min(enc_ar$metadata$mvp_ws[1])
            wlen_max(enc_ar$metadata$mvp_ws[2])
            wlen <- enc_ar$metadata$w
            
            log_print(
                paste0(
                    "observeEvent restore wlen stride | update wlen | Update slider input (", 
                    wlen_min(), ", ", wlen_max(), " ) -> ", wlen 
                ),  debug_group = 'generic')
            
            updateSliderInput(session = session, inputId = "wlen",
                min = wlen_min(),
                max = wlen_max(),
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
                file_flag = FALSE, debug_group =  'generic'
            ); flush.console()
            })
    })

    # Obtener el valor de stride
    enc_ar_stride <- eventReactive(enc_ar(),{
        log_print("--> reactive enc_ar_stride",  debug_group = 'generic')
        stride <- enc_ar()$metadata$stride
        on.exit({log_print(paste0("reactive_enc_ar_stride | --> ", stride),  debug_group = 'generic'); flush.console()})
        stride
    })

    
    enable_disable_embs <- reactive({
        log_print("--> Enable/disable embs", debug_group = 'react')
        on.exit( 
            log_print(
                paste0("Enable/disable embs --> || Changes to ", allow_update_embs()),  
                debug_group = 'react'
            ) 
        )
        if (allow_update_embs()){
            log_print("Enable/disable embs || enable embs", debug_group='react')
            updateActionButton(session, "play_embs", label = "Stop embeddings", icon = shiny::icon("pause"))
            shinyjs::enable("embs")
        } else {
            log_print("Enable/disable embs || disable embs", debug_group = 'react')
            updateActionButton(session, "play_embs", label = "Get Embeddings!", icon = shiny::icon("play"))
            shinyjs::disable("embs")
        }
    })

    

    observeEvent(input$wlen, {
        req(input$wlen)
        log_print(mssg = paste0("--> observeEvent input_wlen | update slide stride value | wlen ",  input$wlen),  debug_group = 'generic')
        tryCatch({
            old_value = input$stride
            if (input$stride == 0 | input$stride == 1){
                old_value = enc_ar_stride()
                log_print(paste0("enc_ar_stride: ", old_value),  debug_group = 'generic')
            }
            
            freezeReactiveValue(input, "stride")
            
            log_print(paste0("oserveEvent input_wlen | update slide stride value | Update stride to ", old_value),  debug_group = 'generic')
        
            updateSliderInput(
                session = session, inputId = "stride", 
                min = 1, max = input$wlen, 
                value = ifelse(old_value <= input$wlen, old_value, 1)
            )

        }, error = function(e){
            log_print(paste0("observeEvent input_wlen | update slide stride value | Error | ", e$message), file_flag = FALSE,  debug_group = 'generic')
        }, warning = function(w) {
            message(paste0("observeEvent input_wlen | update slide stride value | Warning | ", w$message))
        })
        on.exit({
            log_print(paste0( 
            "observeEvent input_wlen | update slide stride value | Finally |  wlen min ",  
            1, " max ", input$wlen, " current value ", input$stride, " -->"), 
            file_flag = FALSE, file_path = LOG_PATH, log_header = LOG_HEADER,  debug_group = 'generic'
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
    
    # Update time series variables
    observe({
        req(play(), ts_ar(), tsdf())
        log_print("--> observe update ts variables (1) || Tsdf modified",  debug_group = 'main')
            on.exit(log_print(paste0(" observe update ts variables (1) || ts variables ", ts_variables_str(ts_variables), " -->"), debug_group = 'main'))
        if (! input$embs_preprocess || is.null(tsdf_ready_preprocessed()) ){
            ts_variables <<- tsdf_variables_no_preprocess(tsdf(), NULL)
            tsdf_ready(TRUE)
            ts_vars_selected_mod(TRUE)
        } else {
            ts_variables <<- tsdf_variables_preprocess(tsdf(), tsdf_preprocessed())
            tsdf_ready(TRUE)
            tsdf_ready_preprocessed(TRUE)
            ts_vars_selected_mod(TRUE)
        }
    })

    # Update ts_variables reactive value when time series variable selection changes
    observeEvent(input$select_variables, {
        log_print("--> input$select_variables mod || update ts_variables$selected",  debug_group = 'main')
        on.exit({log_print("input$select_variables mod || update ts_variables$selected -->",  debug_group = 'main'); flush.console()})
        ts_variables$selected <<- input$select_variables
    })
    
    # Observe to check/uncheck all variables
    observeEvent(input$selectall,{
        ts_vars_selected_mod(TRUE)
        send_log("Select all variables_start", session)
        on.exit({send_log("Select all variables_end", session)})
        log_print("--> observe selectall")
        if ( input$preprocess_dataset ) { req(ts_variables$preprocessed) }
        req(ts_variables$complete)
        ts_variables$selected <<- if (input$selectall %% 2 == 0){
            ts_variables$complete
        } else { NULL }
        log_print(paste0( "observe selectall | ts_variables: ", ts_variables_str(ts_variables), "-->"), debug_level = "debug")
    })

    # Update interface config when ts_variables changes
    observe({
        req(ts_vars_selected_mod())
        log_print("--> observeEvent ts_variables selected | update select variables choices",  debug_group = 'main')
        on.exit({
            log_print(
                paste0(
                    "observeEvent ts_variables selected | update select variables choices | ts_variables:",
                    ts_variables_str(ts_variables)," -->"
                ),
                debug_group = 'main'
            ); 
            flush.console()
        })
        updateCheckboxGroupInput(
            session     = session,
            inputId     = "select_variables",
            choices     = ts_variables$complete,
            selected    = ts_variables$selected
        )
        ts_vars_selected_mod(FALSE)
    }, label = "select_variables")
       
    # Update precomputed_clusters reactive value when the input changes
    observeEvent(input$clusters_labels_name, {
        log_print("--> observe | precomputed_cluster selected ",  debug_group = 'generic')
        precomputed_clusters$selected <- req(input$clusters_labels_name)
        log_print(
            paste0("observe | precomputed_cluster selected --> | ", 
            precomputed_cluster$selected
        ),  debug_group = 'generic')
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
        log_print("--> observe event calculate_clusters | update clusters_config", debug_group = 'button')
        clusters_config$metric_hdbscan <- req(input$metric_hdbscan)
        clusters_config$min_cluster_size_hdbscan <- req(input$min_cluster_size_hdbscan)
        clusters_config$min_samples_hdbscan <- req(input$min_samples_hdbscan)
        clusters_config$cluster_selection_epsilon_hdbscan <- req(input$cluster_selection_epsilon_hdbscan)
        send_log("Clusters config_end", session)
        on.exit({log_print("observe event calculate_clusters | update clusters_config -->", debug_group = 'button')})
    })
    
    
    # Observe the events related to zoom the projections graph
    observeEvent(input$zoom_btn, {
        send_log("Zoom btn_start", session)
        log_print("--> observeEvent zoom_btn",  debug_group = 'button')
        on.exit(log_print(paste0("--> observeEvent zoom_btn ", isTRUE(input$zoom_btn)),  debug_group = 'button'))
        
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
    },
    ignoreInit=TRUE
)
    
    
    # Observe the events related to change the appearance of the projections graph
    observeEvent(input$update_prj_graph,{
        send_log("Update prj graph_start", session)
        log_print(
            "Update prj graph", 
            file_flag   = TRUE, 
            file_path   = LOG_PATH, 
            log_header  = LOG_HEADER,
            debug_group = 'main'
        )
        
        style_values <- list(
            path_line_size  = input$path_line_size,
            path_alpha      = input$path_alpha,
            point_alpha     = input$point_alpha,
            point_size      = input$point_size
        )
        
        if (!is.null(style_values)) {
            config_style$path_line_size <- style_values$path_line_size
            config_style$path_alpha     <- style_values$path_alpha
            config_style$point_alpha    <- style_values$point_alpha
            config_style$point_size     <- style_values$point_size
        } else {
            config_style$path_line_size <- NULL
            config_style$path_alpha     <- NULL
            config_style$point_alpha    <- NULL
            config_style$point_size     <- NULL
        }
        send_log("Update prj graph_end", session)
    })

    
    observeEvent(input$stride, {
        enc_input_ready(FALSE)
    })



    ###############
    #  REACTIVES  #
    ###############
    
    observeEvent(ts_ar(), {
        tsdf_path(file.path(DEFAULT_PATH_WANDB_ARTIFACTS, ts_ar()$metadata$TS$hash))
        enc_input_path(tsdf_path())
    })

    data_feather <- reactive({
        req(! is.null(tsdf_preprocessed()))
        data <- as.data.frame(tsdf_preprocessed())
        log_print(
            paste0("data_feather || Before check data types data ~ ", 
            dim(data)
        ), debug_group = 'force'
        )
        data <- data.frame(
            lapply(data, function(col) {
                if (is.matrix(col)) return(as.vector(col))  # Matrices a vectores
                if (is.factor(col)) return(as.character(col))  # Factores a caracteres
                #if (inherits(col, "POSIXct")) return(as.character(col))  # Fechas a caracteres
                return(col)
            })
        )
        print(class(data))
        print(str(data))
        lapply(data, class)
        log_print(paste0("data_feather || data ~ ", dim(data)), debug_group = 'force')
        log_print(paste0("data_feather || data$timeindex ~ ", length(data$timeindex_preprocessed)), debug_group = 'force')
        log_print(paste0("data_feather || data[[1]] ~ ", length(data[[1]])), debug_group = 'force')
        indexname <- "timeindex_preprocessed"
        #data <- data[, c(indexname, setdiff(names(data), indexname))]
        index <- data[[indexname]]
        data <- data %>% select(-all_of(indexname))
        log_print(paste0("data_feather || data$DataFrame  "), debug_group = 'force')
        py_data <- pd$DataFrame(data = data,index = index)
        log_print(paste0("data_feather || data ~ --> ", dim(py_data)), debug_group = 'force')
        py_data
    })
    
    path_comp <- reactive ({
        log_print("--> path_comp || ", debug_group = 'force')
        on.exit({log_print("path_comp --> || ", debug_group = 'force')})
        if (input$embs_preprocess){
            enc_input_path(
                file.path(DEFAULT_PATH_WANDB_ARTIFACTS, paste0(ts_ar()$metadata$TS$hash, '_preprocess'))
            )
            path <- enc_input_path()
            log_print(paste0("path_comp || Preprocess ", path), debug_group = 'force')
            req(tsdf_preprocessed())
            log_print(paste0("path_comp || path ", path), debug_group = 'force')
            dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
            tryCatch({
                data <- data_feather()
                log_print(paste0("path_comp || ",  "data" %dimstr% data), debug_group='force')
                write_feather(data, path, compression = 'lz4')
                log_print(paste0("path_comp || Preprocessed dataset saved at: ", path), debug_group='force')
            }, error = function(e) {
                stop(paste0("path_comp || Error writing data ", dim(data), " into " , path, ": ", e$message))
            })

        } else {
            enc_input_path(tsdf_path())
            log_print(paste0("path_comp || Dataset saved at: ", enc_input_path()), debug_group='force')
        }
        enc_input_path()
    })

    observe({
        log_print(
            paste0("--> observe X | Before req | tsdf_ready ", 
            tsdf_ready(), 
            " | wlen ", input$wlen, 
            " | stride ", input$stride,
            " | allow update embs ", allow_update_embs(),
            " | play_prjs ", play_prjs(),
            " | tsdf_ready_preprocessed ", tsdf_ready_preprocessed(),
            " | embs preprocess ", input$embs_preprocess
        ), debug_group = 'force')
        req(
            tsdf_ready(), 
            input$wlen != 0, 
            input$stride != 0,
            allow_update_embs(),
            play_prjs(),
            ! (!tsdf_ready_preprocessed() && input$embs_preprocess)
        )
        # -- Intentando mejorar la reactividad ---
        input$embs_preprocess
        # --- FIN  Intentando mejorar la reactividad ---
        log_print("observe X | Update Sliding Window", debug_group = 'debug')
        log_print(
            paste0(
                "observe X | wlen ", input$wlen, 
                " | stride ", input$stride, 
                " | tsdf_ready() ", tsdf_ready(), 
                " | ts_vars ", ts_variables_str(ts_variables),
                " | Let's prepare data"
            ), debug_group = 'debug'
        )
        log_print("observe X | SWV")
        t_x_0 <- Sys.time()
        if (
            ! enc_input_ready()
        ) {     
            req(play())
            log_print(
                paste0( 
                    " Enc input | observe X | ts_variables ", 
                    ts_variables_str(ts_variables)
                ),
                debug_group = 'debug'
            )
            log_print("Enc input | Update X", debug_group = 'debug')
            log_print("Enc input | ReactiveVal X | Update Sliding Window", debug_group = 'debug')
            log_print(paste0("Enc input | observe X | wlen ", input$wlen, " | stride ", input$stride, " | Let's prepare data"), debug_group = 'debug')
            log_print(paste0("Enc input | observe X | ts_ar - id ", ts_ar()$id, " - name ", ts_ar()$name), debug_group = 'main')
            ############## SLIDING WINDOW VIEW
            path <- path_comp()
            log_print(paste0("Enc input | observe X | path: ", path), debug_group = 'main')
            enc_input <- dvats$exec_with_feather_k_output(
                function_name   = "prepare_forecasting_data",
                module_name     = "tsai.data.preparation",
                path            = path,
                k_output        = as.integer(0),
                verbose         = as.integer(1),
                time_flag       = TRUE,
                fcst_history    = input$wlen
            )
            ### Selecting indexes in the sliding window view version ###
            log_print(paste0("Enc input | observe X | 1) ", "enc_input" %dimstr% enc_input), debug_group = 'main')
            indexes <- seq(1, dim(enc_input)[1], input$stride)
            enc_input <- enc_input[indexes,,,drop = FALSE]
            log_print(
                paste0("Enc input | observe X | 2)", "enc_input" %dimstr% enc_input), 
                debug_group = 'main'
            )
            log_print(
                paste0(
                    "Enc input | observe X | Update sliding window | Apply stride ", input$stride,
                    " | ", "X=enc_input" %dimstr% enc_input
                ),
                debug_group = 'main'
            )
            on.exit({log_print("Enc input | observe X -->", debug_group = 'main'); flush.console()})
            enc_input_ready(TRUE)
            X(enc_input)
            allow_update_embs(TRUE)
        } else {
            log_print("Enc input | observe X | X already updated", debug_group = 'main')
        }

        t_x_1 <- Sys.time() 
        t_sliding_window_view = t_x_1 - t_x_0
        log_print(paste0("observe X | SWV: ", t_sliding_window_view, " secs "), TRUE, LOG_PATH, LOG_HEADER)
        temp_log <<- log_add(
            log_mssg            = temp_log, 
            function_           = "observe X | SWV",
            cpu_flag            = input$cpu_flag,
            dr_method           = input$dr_method,
            clustering_options  = input$clustering_options,
            zoom                = input$zoom_btn,
            time                = t_sliding_window_view,
            mssg                = "Compute Sliding Window View"
        )
        on.exit({
            log_print(paste0(
                "observe X | Update sliding window | Exit ", 
                input$stride,
                " | ",
                "enc_input" %dimstr% X(),
                " | ts_variables ", ts_variables_str(ts_variables),
                "-->"
            )); flush.console()
        })
        X()
    })
    
    reset_reactiveVals <- function(type = c("all", "tsdf", "preprocess", "prjs")) {
        type <- match.arg(type)
        isolate({
            if (type == "all" || type == "tsdf") {
                tsdf_ready(FALSE)
                tsdf_ready_preprocessed(TRUE)
                enc_input_ready(FALSE)
                tsdf(NULL)
                tsdf_concatenated(NULL)
                get_tsdf_prev(NULL)
                ts_vars_selected_mod(FALSE)
                play(FALSE)
            }
            if (type == "all" || type == "preprocess") {
                preprocess_dataset_prev(FALSE)
                tsdf_preprocessed(NULL)
                tsdf_preprocessed_params(NULL)
                if (type == "preprocess") {
                    tsdf_ready_preprocessed(TRUE)
                }
                print(paste0("TSDF READY A TRUE ", tsdf_ready_preprocessed())) #quitar
            }
            if (type == "all" || type == "prjs") {
                prjs(NULL)
                embs(NULL)
                embs_complete_cases(NULL)
                enc(NULL)
                cached_embeddings(NULL)
                embs_params(
                    list(
                        dataset     = NULL,
                        encoder     = NULL, 
                        wlen        = NULL, 
                        stride      = NULL, 
                        fine_tune   = NULL,
                        path        = NULL
                    )
                )
                allow_update_embs(FALSE)
            }
        })
    }




    # Time series artifact
    observeEvent(input$dataset, {
        log_print(paste0("--> eventReactive ts_ar | Update dataset artifact | hash ", input$dataset), debug_group = 'react')
        on.exit({
            log_print(
                paste0(
                    "eventReactive ts_ar ",
                    "tsdf_ready? ", tsdf_ready(),
                    " -->"
                ),
                debug_group = 'react'
            ); flush.console()
        } )
        # -- Reset tsdf
        reset_reactiveVals("tsdf")
        ar <- api$artifact(input$dataset, type='dataset')
        # -- Reset preprocess    
        reset_reactiveVals("preprocess")
        updateCheckboxInput(
            session = session,
            inputId = "preprocess_dataset",
            value   = FALSE
        )
        # -- Reset play button
        play(FALSE)
        update_play_pause_button()
        # -- Reset embs & encoder
        reset_reactiveVals("prjs")
        enable_disable_embs()
        log_print(paste0("eventReactive ts_ar || tsdf_ready ", tsdf_ready()), debug_group = 'debug')
        ts_ar(ar)
    })

    observe({
        if (nrow(temp_log) > 0) {
            #Todo: Quitar
            print ("Observe temp log")
            #print(temp_log)
            #--- hasta aqui --
            #new_record <- cbind(
            #    execution_id= execution_id, 
            #    dataset     = ts_ar()$name,
            #    encoder     = ifelse(is.null(input$encoder), " ", input$encoder),
            #    show_lines  = input$show_lines,

            #    point_alpha = input$point_alpha,
            #    temp_log
            #)
            print(paste0("Execution_id: ", execution_id))
            print(paste0("ts_ar_name: ", ts_ar()$name))
            print(paste0("nrows: ", ts_ar()$name))
            print(paste0("show_lines: ", input$show_lines))
            print(paste0("point_alpha: ", input$point_alpha))

            new_record <- cbind(
                execution_id    = rep(execution_id, nrow(temp_log)), 
                dataset         = rep(ts_ar()$name, nrow(temp_log)),
                encoder         = rep(ifelse(is.null(input$encoder), "undefined", input$encoder), nrow(temp_log)),
                show_lines      = rep(input$show_lines, nrow(temp_log)),
                point_alpha     = rep(ifelse(is.null(input$point_alpha), "undefined", input$point_alpha), nrow(temp_log)),
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
            LOG_PATH <<- toguether_log_path
            log_print(paste0(">>>> Toguether Log path: ", toguether_log_path))   
        } else {
            new_log_path <- paste0(toguether_log_path, "-", ts_ar()$name, ".log")  # Construye el nuevo log_path
            LOG_PATH <<- new_log_path
            log_print(paste0(">>>> New Log path: ", new_log_path))   
        }
    })

    
    observe({
        on.exit({
            log_print(
                paste0(" Observe Log header ", LOG_HEADER), 
                debug_group = 'tmi'
            )
        })
        log_header_ = paste0(
            ts_ar()$name, " | ", 
            execution_id ," | ", 
            input$cpu_flag, " | ", 
            input$dr_method, " | ", input$clustering_options, " | ", input$zoom_btn)
        LOG_HEADER <<- log_header_
    })
    
    # Get timeseries artifact metadata
    ts_ar_config = reactive({
        log_print("--> reactive ts_ar_config | List used artifacts", debug_group = 'main')
        on.exit({log_print("reactive ts_ar_config -->", debug_group = main); flush.console()})
        ts_ar = req(ts_ar())
        log_print(paste0("reactive ts_ar_config | List used artifacts | hash", ts_ar$metadata$TS$hash), debug_group = 'debug')
        list_used_arts = ts_ar$metadata$TS
        list_used_arts$vars = ts_ar$metadata$TS$vars %>% stringr::str_c(collapse = "; ")
        list_used_arts$name = ts_ar$name
        list_used_arts$aliases = ts_ar$aliases
        list_used_arts$artifact_name = ts_ar$name
        list_used_arts$id = ts_ar$id
        list_used_arts$created_at = ts_ar$created_at
        list_used_arts
    })

   
   # Encoder
    #enc_comp <- eventReactive(
        #enc_ar(), 
    #{
    observe({
        req(enc_ar(), tsdf_ready())
        log_print(paste0("eventReactive enc_comp || Before req || dataset ", input$dataset, " | encoder | ", input$encoder), debug_group = 'tmi')
        req(input$dataset, input$encoder)
        log_print("--> eventReactive enc | load encoder ", debug_group = 'react')
        encoder_artifact <- enc_ar()
        encoder_read_option <- ""
        encoder_artifact_dir <- ""
        encoder_filename <- encoder_artifact$metadata$ref$hash
        default_path <- file.path(DEFAULT_PATH_WANDB_ARTIFACTS, encoder_filename)
        enc(NULL)

        log_print(paste0("eventReactive enc | load encoder | Check if the encoder file exists: ", default_path), debug_group = 'debug')

        if (file.exists(default_path)) {
            log_print(paste0("eventReactive enc | load encoder ", encoder_filename ," | --> Load from binary file "), debug_group = 'debug')
            # --- Load from binary file --- #
            encoder_read_option <- "Load from binary file"
            enc(py_load_object(default_path))

        } else { # If the encoder file has not been found in the default path
            # --- Download from W&B and load from binary file --- #
            encoder_read_option <- "Download from Weights & Biases and load from binary file"
            log_print(paste0("eventReactive enc | load encoder ",encoder_filename ," | ", encoder_read_option," | --> Load from binary file "), debug_group = 'debug')
            tryCatch({
                log_print(paste0("eventReactive enc | Download encoder's artifact ",encoder_filename, ", ",enc_ar()$name))
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

            log_print(paste0("eventReactive enc | Download from Weight & Biases | encoder artifact dir: ", encoder_artifact_dir), debug_group = 'debug')

            encoder_path <- file.path(encoder_artifact_dir, encoder_filename)
            log_print(paste0("eventReactive enc | Download from Weight & Biases | encoder path: ", encoder_path), debug_group = 'debug')
            # Move the file to the default path
            file.copy(
                from        = encoder_path, 
                to          = default_path, 
                overwrite   = TRUE, 
                recursive   = FALSE, 
                copy.mode   = TRUE
            )
            # Load from binary file
            enc (py_load_object(default_path))
            if (is.null(enc())) {
                stop("Encoder null after loading from the binary file. Something went wrong.")
            }
        } # End of else 
        
        
        on.exit({log_print(paste0("eventReactive enc | load encoder | stride ", input$stride, "-->"), debug_group = 'react'); flush.console()})
        enc()
    })

    embs_kwargs <- reactive({
        res <- list()
        dataset <- X()
        batch_size <- as.integer(dim(dataset)[1])
        encoder <- input$encoder
        cpu_flag = ifelse(input$cpu_flag == "CPU", TRUE, FALSE)
        if (grepl("moment", encoder, ignore.case = TRUE)) {
            log_print("embs_kwargs | Moment", debug_group = 'debug')
            res <- list(
                batch_size      = batch_size,
                cpu             = cpu_flag,
                to_numpy        = TRUE,
                verbose         = as.integer(1),
                padd_step       = input$padd_step, 
                average_seq_dim = TRUE
            )
        } else if (grepl("moirai", encoder, ignore.case = TRUE)) {
            log_print("embs_kwargs | Moirai", debug_group = 'debug')
            size <- sub(".*moirai-(\\w+).*", "\\1", encoder)
            res <- list(
                cpu             = cpu_flag,
                to_numpy        = TRUE,
                batch_size      = batch_size,
                average_seq_dim = TRUE,
                verbose         = as.integer(2),
                patch_size      = as.integer(input$patch_size),
                time            = TRUE
            )
        } else {
            log_print("embs_kwargs | Learner (neither Moment or Moirai)", debug_group = 'debug')
            res <- list(
               stride           = as.integer(1),
               cpu              = cpu_flag,
               to_numpy         = TRUE,
               batch_size       = batch_size,
               average_seq_dim  = TRUE,
               verbose          = as.integer(1)
           )
        }
        res
    })

    ####  CACHING EMBEDDINGS ####
    #embs_comp_or_cached <- reactive({
    #    embs_params_current <- list(
    #        dataset   = input$dataset,
    #        encoder   = input$encoder,
    #        wlen      = input$wlen,
    #        stride    = input$stride,
    #        fine_tune = input$fine_tune,
    #        processed = input$embs_preprocess
    #    )
    #    log_print(paste0(
    #        "embs_comp_or_cached || Before req enc_input_ready ", enc_input_ready(),
    #        " | play ", play(),
    #        " | play prjs ", play_prjs(),
    #        " | allow_update_embs ", allow_update_embs(),
    #        " | X | ", ifelse(is.null(X()), "NULL", "NOT NULL"),
    #        " | enc | ", ifelse(is.null(enc()), "NULL", "NOT NULL"),
    #        " | tsdf_ready | ", tsdf_ready(),
    #        " | tsdf_ready_preprocessed | ", tsdf_ready_preprocessed(),
    #        " | play? ", play(),
    #        " | play prjs? ", play_prjs(),
    #        " | tsdf_preprocessed flag? ", !( input$embs_preprocess && !tsdf_ready_preprocessed())
    #    ), debug_group = 'force')
    #    req(
    #        input$dataset, 
    #        input$encoder, 
    #        input$wlen > 0, 
    #        input$stride > 0,
    #        tsdf_ready(), 
    #        X(), 
    #        enc(), 
    #        enc_input_ready(), 
    #        allow_update_embs(), 
    #        tsdf_ready_preprocessed(),
    #        play(),
    #        play_prjs(),
    #        !( input$embs_preprocess && !tsdf_ready_preprocessed())
    #    )
    #    print("embs_com_or_cached | after req") # Quitar
    #    compute_flag <- reactiveVal_compute_or_cached(cached_embeddings, embs_params(),embs_params_current,"embs_comp")
    #    log_print(paste0("embs_comp_or_cached || --> embs | compute_flag ", compute_flag), debug_group = 'force')
    #    if ( compute_flag ){
    #        res <- embs_comp()
    #        cached_embeddings(res)
    #        shinyjs::disable("embs_comp")
    #    } else {
    #        res <- cached_embeddings()
    #    }
    #    embs_params(embs_params_current)
    #    log_print(paste0("embs_comp_or_cached || res ~", paste(dim(res), collapse=', ')), debug_group = 'force')
    #    embs(res)
    #    res
    #})
    
    # Definir la función
    embs_comp_or_cached <- function() {
        res <- NULL
        embs_params_current <- list(
            dataset   = input$dataset,
            encoder   = input$encoder,
            wlen      = input$wlen,
            stride    = input$stride,
            fine_tune = input$fine_tune,
            processed = input$embs_preprocess,
            path      = enc_input_path()
        )
        log_print(paste0(
            "embs_comp_or_cached || Before req enc_input_ready ", enc_input_ready(),
            " | play ", play(),
            " | play prjs ", play_prjs(),
            " | allow_update_embs ", allow_update_embs(),
            " | X | ", ifelse(is.null(X()), "NULL", "NOT NULL"),
            " | enc | ", ifelse(is.null(enc()), "NULL", "NOT NULL"),
            " | tsdf_ready | ", tsdf_ready(),
            " | tsdf_ready_preprocessed | ", tsdf_ready_preprocessed(),
            " | play? ", play(),
            " | play prjs? ", play_prjs(),
            " | tsdf_preprocessed flag? ", !( input$embs_preprocess && !tsdf_ready_preprocessed())
        ), debug_group = 'force')

        if (
            is.null(input$dataset) ||
            is.null(input$encoder) ||
            input$wlen <= 0 ||
            input$stride <= 0 ||
            !tsdf_ready() ||
            is.null(X()) ||
            is.null(enc()) ||
            !enc_input_ready() ||
            !allow_update_embs() ||
            !tsdf_ready_preprocessed() ||
            !play() ||
            !play_prjs() ||
            (input$embs_preprocess && !tsdf_ready_preprocessed())
        ) {
            log_print("embs_comp_or_cached | invalid parameters")
        } else {
            print("embs_com_or_cached | after req") # Quitar
            compute_flag <- reactiveVal_compute_or_cached(cached_embeddings, embs_params(), embs_params_current, "embs_comp")
            log_print(paste0("embs_comp_or_cached || --> embs | compute_flag ", compute_flag), debug_group = 'force')
            if (compute_flag) {
                res <- embs_comp_func()
                cached_embeddings(res)
                shinyjs::disable("embs_comp")
            } else {
                res <- cached_embeddings()
            }
            embs_params(embs_params_current)
            log_print(paste0("embs_comp_or_cached || res ~", paste(dim(res), collapse=', ')), debug_group = 'force')
        }
        embs(res)
        res
    }

    ###########################

    embs_comp <- reactive({
        req(allow_update_embs(), enc_input_ready(), tsdf(), X())
        log_print(paste0("embs_comp || --> embs_comp | enc_input_ready ", enc_input_ready()), debug_group = 'main')
        log_print(paste0("embs_comp || tsdf ~ (", paste(dim(tsdf()), collapse=', '),")"), debug_group = 'debug')
        log_print(paste0("embs_comp || X ~(", paste(dim(X()), collapse=', '), ")"), debug_group = 'debug')
        log_print(paste0("embs_comp ||get embeddings"), debug_group = 'debug')
        if (torch$cuda$is_available()){
            log_print(paste0("embs_comp || CUDA devices: ", torch$cuda$device_count(), " | current_device: ", torch$cuda$current_device()), debug_group = 'tmi')
        } else {
            force_cpu(TRUE)
            log_print(" || embs_comp || CUDA NOT AVAILABLE", debug_group = 'tmi')
        }
        t_embs_0 <- Sys.time()

        log_print("embs_comp || get embeddings | Get batch size and dataset", debug_group = 'debug')
        dataset_logged_by   <- enc_ar()$logged_by()
        bs                  <- dataset_logged_by$config$batch_size
        stride              <- input$stride 
        log_print(paste0("embs_comp || get embeddings (set stride set batch size) | Stride ", input$stride, " | batch size: ", bs , " | stride: ", stride), debug_group = 'debug')
        log_print(paste0("embs_comp || get embeddings | Original stride: ", dataset_logged_by$config$stride), debug_group = 'debug')
        enc_input <- X()
        
        chunk_size = 10000000 #N*32
        log_print(paste0("embs_comp || get embeddings (set stride set batch size) | Chunk_size ", chunk_size), debug_group = 'debug')
        log_print(paste0("embs_comp || get_enc_embs_set_stride_set_batch_size | ", input$cpu_flag, " | Before"), debug_group = 'debug')
        specific_kwargs <- embs_kwargs()
        enc_l <- req(enc())
        kwargs_common <- list(
            X                   = enc_input,
            enc_learn           = enc_l,
            verbose             = as.integer(2)
        )
        kwargs <- c(kwargs_common, list(stride = as.integer(input$stride)), specific_kwargs)
        
        result <- do.call(
                    dvats$get_enc_embs_set_stride_set_batch_size,
                    kwargs
                )
     
        log_print(paste0("embs_comp || get_enc_embs_set_stride_set_batch_size | ", input$cpu_flag, " | After"), debug_group = 'debug')
        log_print(paste0("embs_comp || get_enc_embs_set_stride_set_batch_size embs ~ | ", dim(result) ), debug_group = 'debug')
        t_embs_1 <- Sys.time()
        diff <- t_embs_1 - t_embs_0
        diff_secs <- as.numeric(diff, units = "secs")
        diff_mins <- as.numeric(diff, units = "mins")
        log_print(paste0("get_enc_embs_set_stride_set_batch_size | ", input$cpu_flag, " | total time: ", diff_secs, " secs thus ", diff_mins, " mins | result ~", dim(result)), TRUE, LOG_PATH, LOG_HEADER, debug_group = 'debug')
        temp_log <<- log_add(
            log_mssg            = temp_log, 
            function_           = "Embeddings",
            cpu_flag            = input$cpu_flag,
            dr_method           = input$dr_method,
            clustering_options  = input$clustering_options,
            zoom                = input$zoom_btn,
            time                = diff, 
            mssg                = "Get encoder embeddings"
        )
        X <- NULL
        gc(verbose=as.integer(1))
        on.exit({log_print(paste0("embs_comp || get embeddings | ", dim(result) , " -->"), debug_group = 'debug'); flush.console()})
        log_print("embs_comp || ...Cleaning GPU", debug_group = 'tmi')
        rm(enc_l, enc_input)
        log_print(paste0("embs_comp || Cleaning GPU... || ", dim(result)), debug_group = 'tmi')
        return(result)
    }) 

        # Definir la función
    embs_comp_func <- function() {
        if (!allow_update_embs() || !enc_input_ready() || is.null(tsdf()) || is.null(X())) {
            return(NULL)
        }

        log_print(paste0("embs_comp || --> embs_comp | enc_input_ready ", enc_input_ready()), debug_group = 'main')
        log_print(paste0("embs_comp || tsdf ~ (", paste(dim(tsdf()), collapse=', '),")"), debug_group = 'debug')
        log_print(paste0("embs_comp || X ~(", paste(dim(X()), collapse=', '), ")"), debug_group = 'debug')
        log_print(paste0("embs_comp ||get embeddings"), debug_group = 'debug')

        if (torch$cuda$is_available()){
            log_print(paste0("embs_comp || CUDA devices: ", torch$cuda$device_count(), " | current_device: ", torch$cuda$current_device()), debug_group = 'tmi')
        } else {
            force_cpu(TRUE)
            log_print(" || embs_comp || CUDA NOT AVAILABLE", debug_group = 'tmi')
        }

        t_embs_0 <- Sys.time()

        log_print("embs_comp || get embeddings | Get batch size and dataset", debug_group = 'debug')
        dataset_logged_by   <- enc_ar()$logged_by()
        bs                  <- dataset_logged_by$config$batch_size
        stride              <- input$stride
        log_print(paste0("embs_comp || get embeddings (set stride set batch size) | Stride ", input$stride, " | batch size: ", bs , " | stride: ", stride), debug_group = 'debug')
        log_print(paste0("embs_comp || get embeddings | Original stride: ", dataset_logged_by$config$stride), debug_group = 'debug')
        enc_input <- X()

        chunk_size = 10000000 #N*32
        log_print(paste0("embs_comp || get embeddings (set stride set batch size) | Chunk_size ", chunk_size), debug_group = 'debug')
        log_print(paste0("embs_comp || get_enc_embs_set_stride_set_batch_size | ", input$cpu_flag, " | Before"), debug_group = 'debug')
        specific_kwargs <- embs_kwargs()
        enc_l <- enc()
        kwargs_common <- list(
            X                   = enc_input,
            enc_learn           = enc_l,
            verbose             = as.integer(2)
        )
        kwargs <- c(kwargs_common, list(stride = as.integer(input$stride)), specific_kwargs)

        result <- do.call(
                    dvats$get_enc_embs_set_stride_set_batch_size,
                    kwargs
                )

        log_print(paste0("embs_comp || get_enc_embs_set_stride_set_batch_size | ", input$cpu_flag, " | After"), debug_group = 'debug')
        log_print(paste0("embs_comp || get_enc_embs_set_stride_set_batch_size embs ~ | ", dim(result) ), debug_group = 'debug')
        t_embs_1 <- Sys.time()
        diff <- t_embs_1 - t_embs_0
        diff_secs <- as.numeric(diff, units = "secs")
        diff_mins <- as.numeric(diff, units = "mins")
        log_print(paste0("get_enc_embs_set_stride_set_batch_size | ", input$cpu_flag, " | total time: ", diff_secs, " secs thus ", diff_mins, " mins | result ~", dim(result)), TRUE, LOG_PATH, LOG_HEADER, debug_group = 'debug')
        temp_log <<- log_add(
            log_mssg            = temp_log,
            function_           = "Embeddings",
            cpu_flag            = input$cpu_flag,
            dr_method           = input$dr_method,
            clustering_options  = input$clustering_options,
            zoom                = input$zoom_btn,
            time                = diff,
            mssg                = "Get encoder embeddings"
        )
        X <- NULL
        gc(verbose=as.integer(1))
        on.exit({log_print(paste0("embs_comp || get embeddings | ", dim(result) , " -->"), debug_group = 'debug'); flush.console()})
        log_print("embs_comp || ...Cleaning GPU", debug_group = 'tmi')
        rm(enc_l, enc_input)
        log_print(paste0("embs_comp || Cleaning GPU... || ", dim(result)), debug_group = 'tmi')
        return(result)
    }



    observeEvent(input$ft_dataset_option, {
        req(input$ft_dataset_option, input$ft_window_percent, input$ft_num_epochs)
        if (input$ft_dataset_option == "use_ft_window_percent") {
          # Set ft_num_windows to NULL and ensure ft_window_percent has its value
          updateTextInput(session, "ft_num_windows", value = NULL)
          updateTextInput(session, "ft_window_percent", value = input$ft_window_percent)
        } else if (input$ft_dataset_option == "use_ft_num_windows") {
          # Set ft_window_percent to NULL and ensure ft_num_windows has its value
          updateTextInput(session, "ft_window_percent", value = NULL)
          updateTextInput(session, "ft_num_windows", value = input$ft_num_windows)
        } else if (input$ft_dataset_option == "full_dataset") {
          # Set both ft_window_percent and ft_num_windows to 0
          updateTextInput(session, "ft_window_percent", value = NULL)
          updateTextInput(session, "ft_num_windows", value = NULL)
        }
      })

    observe({
        log_print("Observe event | Input fine tune | Play fine tune ... Waiting ...", debug_group = 'tmi')
        req(play_fine_tune(), input$fine_tune, enc(), input$ft_df)
        log_print("Observe event | Input fine tune | Play fine tune", debug_group = 'button')
        df <- NULL
        if (
                is.null(tsdf_preprocessed()) 
            ||  ! input$preprocess_dataset 
            ||  input$ft_df == "ft_df_ts"
        ) {
            log_print("Observe event | Input fine tune | Play fine tune | Using the original dataset", debug_group = 'force')
            df <- tsdf()  %>% select(ts_variables$original, - "timeindex")
        } else {
            log_print(
                paste0(
                    "Observe event | Input fine tune | Play fine tune | Using the preprocessed dataset", 
                    " | ts_variables$selected"
                ),
                debug_group = 'force'
            )
            df <- tsdf_preprocessed()  %>% select(ts_variables$preprocessed, - "timeindex_preprocessed")
        }

        dataset_logged_by <- enc_ar()$logged_by()

        fine_tune_kwargs <- list(
            X                               = df,
            enc_learn                       = enc(),
            stride                          = as.integer(1),
            #batch_size                      = as.integer(input$ft_batch_size),
            batch_size                      = as.integer(dataset_logged_by$config$batch_size),
            #cpu                             = ifelse(input$cpu_flag == "CPU", TRUE, FALSE),
            cpu                             = FALSE,
            to_numpy                        = FALSE,
            verbose                         = as.integer(8),
            time_flag                       = TRUE,
            n_windows_percent               = NULL,
            #n_windows_percent               = as.numeric(input$ft_window_percent),
            window_mask_percent             = as.numeric(input$ft_mask_window_percent),
            training_percent                = as.numeric(input$ft_training_percent),
            validation_percent              = as.numeric(input$ft_validation_percent),
            num_epochs                      = as.integer(input$ft_num_epochs),
            shot                            = TRUE,
            eval_pre                        = TRUE,
            eval_post                       = TRUE,
            #optimizer                       = NULL, #torch$optim$AdamW,
            #lr                              = as.numeric(0.00005),
            lr                              = as.numeric(0.001),
            lr_scheduler_flag               = TRUE, #FALSE, 
            #lr_scheduler_name               = "OneCycleLR",
            lr_scheduler_name               = "cosine_with_restarts",
            lr_scheduler_num_warmup_steps   = 100,
            window_sizes                    = list(as.integer(input$wlen)),
            n_window_sizes                  = as.integer(input$ft_num_windows),
            window_sizes_offset             = as.numeric(0.05),
            windows_min_distance            = as.integer(input$ft_min_windows_distance),
            full_dataset                    = input$ft_datset_option == "full_dataset",
            print_to_path                   = FALSE, #TRUE,
            print_path                      = "~/data/logs.txt",
            print_mode                      = "a",
            use_moment_masks                = TRUE,
            mask_stateful                   = ("ft_mask_stateful" %in% input$masking_options),
            mask_future                     = ("ft_mask_future" %in% input$masking_options),
            mask_sync                       = ("ft_sync" %in% input$masking_options),
            analysis_mode                   = dataset_logged_by$config$analysis_mode,
            use_wandb                       = dataset_logged_by$config$dataset_logged_by,
            norm_by_sample                  = dataset_logged_by$config$norm_by_sample,
            norm_use_single_batch           = dataset_logged_by$config$norm_use_single_batch,
            show_plot                       = TRUE, #FALSE
            metrics                         = c(
                dvats_encoder$EvalMSE,
                dvats_encoder$EvalRMSE,
                dvats_encoder$EvalMAE,
                dvats_encoder$EvalSMAPE
                #dvats$encoder$EvalMSE, 
                #dvats$encoder$EvalRMSE, 
                #dvats$encoder$EvalMAE, 
                #dvats$encoder$EvalSMAPE
            ),
            metrics_args        = c(list(squared = FALSE), list(squared = TRUE), list(), list()),
            metrics_names       = c("mse","rmse", "mae", "smape"),
            criterion           = torch$nn$MSELoss(),
            mix_windows         = TRUE,
            register_errors     = FALSE, #TRUE,
            save_best_or_last   = TRUE,
            force_gpu_id        = as.integer(GPU_ID)
        )

        for (key in names(fine_tune_kwargs)) {
            value <- fine_tune_kwargs[[key]]
            if (is.numeric(value) && any(is.na(value))) {
                log_print(paste0("Fine tune kwargs | NaN detected in:", key, "\n"), debug_group = 'debug')
            } else {
                log_print(paste0("Fine tune kwargs | ", key, ": ", fine_tune_kwargs[[key]], "\n"), debug_group = 'debug')
            }
        }

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
        #result <- do.call(dvats$fine_tune_moment_, fine_tune_kwargs)
        result <- do.call(dvats$fine_tune, fine_tune_kwargs)
        t_end <- Sys.time()
        eval_results_pre <- result[[2]]
        eval_results_post <- result[[3]]
        t_shots <- result[[4]]
        t_shot <- result[[5]]
        t_evals <- result[[6]]
        t_eval <- result[[7]]
        enc(result[[8]])
        diff = t_end - t_init
        diff_secs = diff
        diff_mins = diff / 60
        log_print(paste0("Fine tune: ", diff_secs, " s | approx ", diff_mins, "min" ), debug_group = 'time')
        log_print(paste0("Fine tune Python single shots time: ", t_shots, "s" ), debug_group = 'time')
        log_print(paste0("Fine tune Python total shot time: ", t_shot, "s" ), debug_group = 'time')
        log_print(paste0("Fine tune Python single eval steps time: ", t_shots, "s" ), debug_group = 'time')
        log_print(paste0("Fine tune Python total eval time: ", t_shot, "s" ), debug_group = 'time')
        log_print(paste0("Fine tune Python single shots time: ", t_shots, "s" ), debug_group = 'time')
        log_print(paste0("Fine tune eval results pre-tune: ", eval_results_pre, "s" ), debug_group = 'time')
        log_print(paste0("Fine tune eval results post-tune: ", eval_results_post, "s" ), debug_group = 'time')
        update_play_fine_tune_button()
        removeModal()
    })
  
    observe({
        req(input$cpu_flag, force_cpu())
        if (force_cpu()){ 
            flag = ifelse(input$cpu_flag == "CPU", TRUE, FALSE) 
        } else { flag = TRUE }
        flag
    })

    embs_complete_cases_comp <- function(){
        c(lps, lpe, lp) %<-% setup_log_print('ecc')
        lps()
        on.exit({lpe()})
        log_print(paste0("embs_complete_cases || Before complete cases embs ~", paste(dim(embs()), collapse = ', ')), debug_group = 'debug')
        complete_cases <- (embs()[complete.cases(embs()),])
        log_print(paste0("embs_complete_cases || After complete cases embs ~", paste(dim(embs_complete_cases()), collapse = ', ')), debug_group = 'force')
        return(complete_cases)
    }

    embs_preprocess <- observeEvent(input$embs_preprocess, {
        c(lps, lpe, lp) %<-% setup_log_print('oiep')
        lps()
        on.exit({lpe()})
        lp(
            paste0(
                " || before req",
                " | input encoder ", input$encoder,
                " | tsdf_ready_preprocessed? ", tsdf_ready_preprocessed(),
                " | input$embs_preprocess ", input$embs_preprocess
            )
        )
        allow_update_embs(FALSE)
        enable_disable_embs()
        play(FALSE)
        play_prjs(FALSE)
        update_play_pause_button_preprocessed()
        path_comp()
        enc_input_ready(FALSE)
        lp(paste0("feather path: ", enc_input_path()))
    }, ignoreInit=TRUE)
    
    prjs_umap <- reactive({
        req(input$prj_n_neighbors, input$prj_min_dist, input$prj_random_state, embs_complete_cases())
        dvats$get_UMAP_prjs(
            input_data  = embs_complete_cases(), 
            cpu         = cpu_flag(), 
            verbose     = as.integer(1),
            n_neighbors = input$prj_n_neighbors, 
            min_dist    = input$prj_min_dist, 
            random_state= as.integer(input$prj_random_state)
        )
    })
    prjs_tsne <- reactive({
        req( embs_complete_cases(), input$prj_random_state)
        dvats$get_TSNE_prjs(
            X           = embs_complete_cases(), 
            cpu         = cpu_flag(), 
            random_state=as.integer(input$prj_random_state)
        )
    })
    prjs_pca <- reactive({
        req(embs_complete_cases(), input$prj_random_state)
        res <- dvats$get_PCA_prjs(
            X           = embs_complete_cases(), 
            cpu         = cpu_flag(), 
            random_state= as.integer(input$prj_random_state)
            )
        res
    })
    prjs_pca_umap <- reactive({
        log_print(
            paste0(
                "prjs_pca_umap || Before req", 
                " | embs complete cases? ", ! is.null(embs_complete_cases())
            ),
            debug_group = 'debug'
        )
        req(
            embs_complete_cases(), 
            input$prj_random_state, 
            input$prj_n_neighbors, 
            input$prj_min_dist
        )
        log_print("--> prjs_pca_umap", debug_group = 'main')
        on.exit({log_print("prjs_pca_umap -->", debug_group = 'main')})
        embs <- embs_complete_cases()
        res <- dvats$get_PCA_UMAP_prjs(
            input_data  = embs, 
            cpu         = cpu_flag(), 
            verbose     = as.integer(1),
            pca_kwargs  = dict(
                random_state = as.integer(input$prj_random_state),
                n_components = as.integer(input$pca_n_components)
            ),
            umap_kwargs = dict(
                random_state    = as.integer(input$prj_random_state), 
                n_neighbors     = input$prj_n_neighbors, 
                min_dist        = input$prj_min_dist, 
                n_components    = as.integer(2)
            )
        )
        res
    })

    prjs_comp <- reactive({
        log_print(
            paste0(
                "prjs_comp | Before req",
                " || DR: ", input$dr_method, 
                " || embs? ", ! is.null(embs_complete_cases())
            ),
            debug_group = 'debug'
        )
        req(input$dr_method, embs_complete_cases())
        log_print(
            paste0("--> || prjs_comp || Before switch || DR method: ", input$dr_method), 
            debug_group = 'main'
        )
        res <- NULL
        on.exit({log_print(paste0("prjs_comp | res ~", paste(dim(res), collapse=', '), "-->"), debug_group = 'main')})
        res <- switch( input$dr_method,
                UMAP    = prjs_umap(),
                TSNE    = prjs_tsne(),
                PCA     = prjs_pca(),                
                PCA_UMAP= prjs_pca_umap()
            )
        res
    })
    
    prj_object <- reactive({
        c(lps, lpe, lp) %<-% setup_log_print('rpro')
        lps()
        lp("Before prjs_comp")
        t_prj_0 = Sys.time()
        res <- prjs_comp()
        lp(paste0("After prjs_comp res~", dim(res)))
        # TODO: This should be a matrix for improved efficiency
        res <- res %>% as.data.frame
        colnames(res) = c("xcoord", "ycoord")
        flush.console()
        t_prj_1 = Sys.time()
        on.exit({
            lp(
                paste0(
                    "cpu_flag: ", input$cpu_flag, 
                    " | DR: ", input$dr_method, 
                    " | Execution time: ", t_prj_1-t_prj_0 , 
                    " | prjs ~ ", dim(res),
                    " seconds"
                ), 
                file_flag = TRUE, file_path = LOG_PATH, log_header = LOG_HEADER, debug_group = 'time'
            ); 
            lpe()
            temp_log <<- log_add(
                log_mssg            = temp_log,
                function_           = "PRJ Object",
                cpu_flag            = input$cpu_flag,
                dr_method           = input$dr_method,
                clustering_options  = input$clustering_options,
                zoom                = input$zoom_btn,
                time                =  t_prj_1-t_prj_0, 
                mssg                = paste0("Compute projections | prj ~", dim(res)) 
            ); 
            flush.console() 
        })
        res
    })

    

    parallel_posfix <- function(df) {
        
        chunk_size = 100000
        num_chunks = ceiling(nrow(df)/chunk_size)
        chunks=split(df$timeindex, ceiling(seq_along(df$timeindex)/chunk_size))
                
        log_print(paste0("Parallel posfix | Chunks: ", num_chunks), debug_group = 'debug')
        on.exit({
            log_print("Parallel posfix | Make conversion -->", 
            debug_group = 'debug'
            )
        })

        cl = parallel::makeCluster(4)
        parallel::clusterEvalQ(cl, library(fasttime))
                
        log_print(paste0("Parallel posfix | Cluster ", cl, " of ", detectCores()), debug_group = 'debug')
        flush.console()
        
        result <- parallel::clusterApply(cl, chunks, function(chunk) {
            cat("Processing chunk\n")
            flush.console()
            #fasttime::fastPOSIXct(chunk, format = "%Y-%m-%d %H:%M:%S")
            as.POSIXct(chunk)
        })
        stopCluster(cl)
        flush.console()
        return(unlist(result))
    }

    # Load and filter TimeSeries object from wandb
    tsdf_comp <- reactive({            
        if ( input$preprocess_dataset ) { 
            tsdf_ready_preprocessed(FALSE) 
            print(paste0("TSDF READY A FALSE 3", tsdf_ready_preprocessed())) #quitar
        }
        log_print(
            paste0(
                "tsdf_comp || before req",
                " | Input encoder ", input$encoder,
                " | Input dataset ", input$dataset,
                " | ts_ar ", ! is.null(ts_ar())
            ), 
            debug_group = 'debug'
        )
        req(input$encoder, input$dataset, ts_ar(), !tsdf_ready())   
        ts_ar = ts_ar()
        log_print(paste0("--> Reactive tsdf | ts artifact ", ts_ar()), debug_group = 'main')
        flush.console()
        t_init <- Sys.time()
        # Get the full path
        path = file.path(DEFAULT_PATH_WANDB_ARTIFACTS, ts_ar$metadata$TS$hash)
        log_print(paste0("Reactive tsdf | Read feather ", path ), debug_group = 'debug')
        flush.console()
        log_print(paste0("Reactive tsdf | Read feather | Before | ", path), debug_group = 'debug')
        t_0 <- Sys.time()
        df <- tryCatch({ # The perfect case
            # --- Read from feather file --- #
            df <- read_feather(path, as_data_frame = TRUE, mmap = TRUE) %>% rename('timeindex' = `__index_level_0__`) 
            df
        }, error = function(e) {
            # --- Download from Weight & Biases and save the feather for the future --- #
            warning(paste0("Reactive tsdf | Read feather --> | Failed to read feather file: ", e$message))
            log_print(paste0("Reactive tsdf | --> Download from Weight & Biases"), debug_group = 'debug')
            flush.console()
            # Download the artifact and return the dataset's feather local path
            dataset_artifact_dir <- ts_ar$download()
            log_print(
                paste0(
                    "Reactive tsdf | Download from Weight & Biases | dataset artifact dir: ", 
                    dataset_artifact_dir
                ), 
                debug_group = 'debug'
            )
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
            log_print(paste0("Reactive tsdf | Read feather | After | ", path), debug_group = 'debug')
            log_print(
                paste0(
                    "Reactive tsdf | Read feather | Load time: ", 
                    t_1 - t_0, 
                    " seconds | N elements: ", 
                    nrow(df)
                ), TRUE, LOG_PATH, LOG_HEADER, debug_group = 'debug'
            )
            temp_log <<- log_add(
                log_mssg            = temp_log, 
                function_           = "TSDF | Load dataset | Read feather",
                cpu_flag            = input$cpu_flag,
                dr_method           = input$dr_method,
                clustering_options  = input$clustering_options,
                zoom                = input$zoom_btn,
                time                = t_1-t_0, 
                mssg                = "Read feather"
            )
            flush.console()
            log_print(
                paste0(
                    "Reactive tsdf | Execution time: ", t_1 - t_0, " seconds | df ~ ", dim(df),
                    debug_group = 'time'
                )
            )
            flush.console()
            df
        })
        tsdf(df)
        tsdf_ready(TRUE)
        tsdf_concatenated(df)
        tsdf_preprocessed(NULL)
        tsdf_ready_preprocessed(! input$preprocess_dataset)
        print(paste0("TSDF READY A 4 ", tsdf_ready_preprocessed())) #quitar
        allow_update_embs(FALSE)
        enable_disable_embs()
        log_print(
            paste0( 
                "Reactive tsdf | ts_variables ", ts_variables_str(ts_variables),
                " ready? ", ! is.null(ts_variables$complete)
            ), debug_group = 'main'
        )
    })  
    
    observeEvent(input$preprocess_play, {
        log_print("--> Preprocess dataset Play ", debug_group = 'react')
        on.exit({log_print("Preprocess dataset Play -->", debug_group = 'react')})
        if (preprocess_play_flag()) {
            req(tsdf_ready())
            preprocess_dataset_prev(FALSE)
            ts_variables$complete <- ts_variables$original
            ts_variables$selected <- ts_variables$original
            updateActionButton(session, "preprocess_play", label = "Preprocess pause", icon = shiny::icon("pause"))
        } else {
            preprocess_dataset_prev(TRUE)
            updateActionButton(session, "preprocess_play", label = "Preprocess", icon = shiny::icon("play"))
        }
        preprocess_play_flag(!preprocess_play_flag())
        log_print(
            paste0( 
                " || Preprocess dataset Play || Change to ", preprocess_play_flag(),
                " | ts_variables ", ts_variables_str(ts_variables)
            ), debug_group = 'button'
        )
    })
    
    observe({
        req( preprocess_play_flag() ) 
        log_print(
            paste0(
                "--> preprocess dataset || play_flag ", preprocess_play_flag(), 
                " tsdf ready ", tsdf_ready(), 
                " tsdf_preprocessed ready ", tsdf_ready_preprocessed() 
            ), debug_group = 'main')
        on.exit( 
            log_print(paste0("preprocess dataset || ts_variables ", ts_variables_str(ts_variables) ," --> "), debug_group = 'main')
        )
        log_print(
            paste0(
                "Preprocess dataset || input preprocess ", input$preprocess_dataset, 
                " play_flag ", preprocess_play_flag()
            ),
            debug_group = 'debug'
        )
        on.exit(
            log_print(
                paste0("Preprocess dataset ", paste(colnames(tsdf_preprocessed), collapse = ', '," --> ")),
                debug_group = 'main'
            )
        )
        params_current <- list(
            dataset   = input$dataset,
            wlen      = input$wlen,
            stride    = input$stride,
            type      = input$task_type,
            methods1  = input$methods_point,
            methods2  = input$methods_sequence,
            methods3  = input$methods_segments,
            methods4  = input$methods_trends
        )
        compute_flag <- reactiveVal_compute_or_cached(
            object                  = tsdf_preprocessed, 
            params_prev             = tsdf_preprocessed_params(),
            params_now              = params_current,
            compute_function_name   = "tsdf_preprocessed"
        )
        log_print(paste0("Preprocess dataset || Compute flag ", compute_flag), debug_group = 'debug')
        if(compute_flag){
            log_print(
                paste0(
                    "Preprocess dataset || Apply preprocessing | Colnames ", 
                    paste(colnames(tsdf()), collapse = ', '),
                    " | sections ", 
                    sections_count(),
                    " | sections size ",
                    sections_size()
                ),
                debug_group = 'debug'
            )
            tsdf_preprocessed(
                apply_preprocessing(
                    dataset     = tsdf(),
                    task_type   = input$task_type,
                    methods     = switch(
                        input$task_type, 
                        "point_outlier"     = input$methods_point,
                        "sequence_outlier"  = input$methods_sequence,
                        "segments"          = input$methods_segments,
                        "trends"            = input$methods_trends,
                    ),
                    wlen                    = input$wlen,
                    sections                = sections_count(),
                    section_size            = sections_size()
                )
            )
            tsdf_preprocessed_params(params_current)
            # Confirm update
            tsdf_ready_preprocessed(TRUE)
        } else {
            log_print(paste0("Preprocess dataset || Use cached values "), debug_group = 'debug')
        }
        log_print(paste0("Preprocess dataset || tsdf_preprocessed~(", paste0(dim(tsdf_preprocessed()), collapse = ', '),")"), debug_group = 'force')
    })
   
    # Auxiliary object for the interaction ts->projections
    tsidxs_per_embedding_idx <- reactive({
        #window_indices = get_window_indices(embedding_indices, input$wlen, input$stride)
        req(projections())
        ts_indices <- get_window_indices(1:nrow(isolate(projections())), w = input$wlen, s = input$stride)
        ts_indices
    })
    
    # Filter the embedding points and calculate/show the clusters if conditions are met.
    projections <- reactive({
        log_print(
            paste0(
                "projections || Before req", 
                " | dr_method ", input$dr_method,
                " | tsdf ready ", tsdf_ready(),
                " | update embs ", allow_update_embs(),
                " | enc_input_ready? ", enc_input_ready()
            ),
            debug_group = 'debug'
        )
        req(input$dr_method, tsdf_ready(), allow_update_embs(), clustering_options$selected)
        log_print("--> projections", debug_group = 'main')
        log_print("projections || before prjs", debug_group = 'debug')
        prjs <- prj_object()
        log_print(
            paste0("projections || Compute clusters? ", clustering_options$selected), 
            debug_group = 'debug'
        )
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
                log_print(paste0("Projections | Score ", score), debug_group = 'debug')
    
                prjs$cluster <- clusters$labels_
                tcl_1 = Sys.time()
                log_print(paste0("Compute clusters | Execution time ", tcl_1 - tcl_0), TRUE, LOG_PATH, LOG_HEADER, debug_group = 'debug')
                temp_log <<- log_add(
                    log_mssg                = temp_log, 
                    function_               = "Projections | Hdbscan",
                    cpu_flag                = input$cpu_flag,
                    dr_method               = input$dr_method,
                    clustering_options      = input$clustering_options,
                    zoom                    = input$zoom,
                    time                    = tcl_1-tcl_0, 
                    mssg                    = "Compute clusters"
                )
                prjs$cluster
             })
        on.exit({
            log_print(
                paste0("Projections |", "prjs" %dimstr% prjs, "-->"), 
                debug_group = 'main'
            ); 
            flush.console()
        })
        prjs(prjs)
        prjs
    })

    update_palette <- reactive({
        prjs <- req(prjs())
        if ("cluster" %in% names(prjs)) {
            unique_labels <- unique(prjs$cluster)
            log_print(paste0("Update palete, unique_labels: ", unique_labels), debug_group = 'debug')

            # Selecciona colores específicos según el número de clusters
            num_labels <- length(unique_labels)

            if (num_labels == 1) {
                # Un solo cluster, asignar color rojo oscuro
                colour_palette <- c("#8B0000")
            } else if (num_labels == 2) {
                # Dos clusters, asignar rojo oscuro y azul oscuro
                colour_palette <- c("#8B0000", "#00008B")
            } else if (num_labels <= 9) {
                # Tres o más clusters pero menos de 9, usa la paleta Set1 de colores distintivos
                #colour_palette <- brewer.pal(num_labels, "Set1")
                colour_palette <- brewer.pal(num_labels, "Dark2")
            } else {
                # Más de 9 clusters, usa colores aleatorios vibrantes
                colour_palette <- distinctColorPalette(num_labels)
            }

        } else {
            colour_palette <- "red"
        }

        colour_palette
    })
    

    start_date <- reactive({
        sd <- tsdf()$timeindex[1]
        on.exit({log_print(paste0("start_date --> ", sd), debug_group = 'debug'); flush.console()})
        sd
    })

    end_date <- reactive({
        end_date_id = as.integer(100000)
        end_date_id = min(end_date_id, nrow(tsdf()))
        ed <- tsdf()$timeindex[end_date_id]
        on.exit({log_print(paste0("end_date --> ", ed), debug_group = 'debug'); flush.console()})
        ed
    })
    
    observe({
        req(preprocess_play_flag(), tsdf_ready_preprocessed(), tsdf())
        tsdf_ <- tsdf()
        log_print(paste0("ts_concatenated | colnames before concat | ", paste(colnames(tsdf_), collapse = ', ')), debug_group = 'debug')
        log_print(paste0("ts_concatenated || ts variables Before concat ", ts_variables_str(ts_variables)), debug_group = 'debug')
        log_print(paste0("ts_concatenated | Concat preprocessed "), debug_group = 'debug')
        req(tsdf_preprocessed())
        log_print(paste0("ts_concatenated | Before | Colnames ", paste(colnames(tsdf_), collapse = ', ')), debug_group = 'debug')
        tsdf_ <- concat_preprocessed(
            dataset                 = tsdf(),
            dataset_preprocessed    = tsdf_preprocessed(),
            ts_variables_selected   = NULL
        )
        # Update ts variables list
        log_print(paste0("ts_concatenated | tsdf preprocessed || ts variables ", ts_variables_str(ts_variables)), debug_group = 'debug')
        log_print(paste0("ts_concatenated | tsdf preprocessed || colnames ", paste(colnames(tsdf_), collapse = ', ')), debug_group = 'debug')
        ts_variables <<- tsdf_variables_preprocess(tsdf(), tsdf_preprocessed())
        ts_vars_selected_mod(TRUE)
        tsdf_concatenated(tsdf_)
        log_print(paste0("ts_concatenated | ts variables || ts variables After concat: ", ts_variables_str(ts_variables)), debug_group = 'debug')
    })

    observeEvent( preprocess_play_flag(), {
        # Leads to errors in reactiveness. Take care with the transformations.
        # req(! preprocess_play_flag(), tsdf_ready(), tsdf())
        # tsdf_preprocessed(NULL)
        # tsdf_concatenated(tsdf())
        req(tsdf_ready())
        on.exit({log_print("--> observe preprocess_play_flag", debug_group = 'react')})
        on.exit({log_print("observe preprocess_play_flag -->", debug_group = 'react')})
        if ( !preprocess_play_flag() ){
            if ( tsdf_ready_preprocessed() ){
                log_print("observe preprocess_play_flag || Maintain preprocessed dataset, update select to show only the original time series.", debug_group = 'debug')
                ts_variables$selected <<- setdiff( ts_variables$selected, ts_variables$preprocess )
                #ts_variables$complete <<- setdiff( ts_variables$selected ) # Think if we want to maintain or not the complete dataset and if it would be neccesary one more checkbox/global variable
                ts_vars_selected_mod(TRUE)
            } 
        } else {
            if ( tsdf_ready_preprocessed() ){
                log_print("observe preprocess_play_flag || Update ts_variables$selected to show preprocessed variate.", debug_group = 'debug')
                ts_variables$selected <<- c( ts_variables$selected, ts_variables$preprocess )
                ts_vars_selected_mod(TRUE)
            }
        }
        #log_print("observe preprocess_play_flag || Compute projections plot", debug_group = 'debug')
        #allow_update_embs(TRUE)
        #projections_plot_comp()
    })

    ts_plot_base <- reactive({
        req(
	    tsdf_ready(), 
	    input$select_variables, 
	    tsdf_concatenated(),
	    !( ! tsdf_ready_preprocessed() && input$embs_preprocess)
	)
        log_print("--> ts_plot_base", debug_group = 'main')
        on.exit({log_print("ts_plot_base -->", debug_group = 'main'); flush.console()})
        start_date  = start_date()
        end_date    = end_date()
        log_print(paste0("ts_plot_base | start_date: ", start_date, " end_date: ", end_date), debug_group = 'debug')
        t_ts_plot_0 <- Sys.time()
        tsdf_ <- tsdf_concatenated()
        log_print(paste0("ts_plot_base | colnames before select | ", paste(colnames(tsdf_), collapse = ', ')), debug_group = 'force')
        log_print(paste0("ts_plot_base | ts_variables before select | ", ts_variables_str(ts_variables)), debug_group = 'force')
        tsdf_ <- tsdf_ %>% select(ts_variables$selected, - "timeindex")
        log_print(paste0("ts_plot_base | colnames | ", paste(colnames(tsdf_), collapse = ', ')), debug_group = 'debug')
        req(tsdf_)
        tsdf_xts <- xts(tsdf_, order.by = tsdf()$timeindex)
        t_ts_plot_1 <- Sys.time()
        log_print(paste0("ts_plot_base | tsdf_xts time", t_ts_plot_1-t_ts_plot_0), debug_group = 'time') 
        temp_log <<- log_add(
          log_mssg            = temp_log, 
          function_           = "Reactive X | SWV",
          cpu_flag            = input$cpu_flag,
          dr_method           = input$dr_method,
          clustering_options  = input$clustering_options,
          zoom                = input$zoom_btn,
          time                = t_ts_plot_1-t_ts_plot_0,
          mssg                = "tsdf_xts"
        )
        log_print(paste0("ts_plot_base | head tsdf: ", head(tsdf_xts)), debug_group = 'tmi')
        log_print(paste0("ts_plot_base | tail tsdf: ", tail(tsdf_xts)), debug_group = 'tmi')
        ts_plt = dygraph(
                tsdf_xts,
                width="1100px", height = "400px"
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
        ts_plt
    })

    process_prjs_object <- reactive({
        log_print("--> process_prjs_object", debug_group = 'debug')
        on.exit({log_print("process_prjs_object-->", debug_group = 'debug');})
        prjs <- prj_object()
        #log_print(head(prjs), debug_group = 'debug')
        # Get current rownames 
        log_print(
            paste0("process_prjs_object | Rownames pre [", paste(rownames(prjs), collapse = ', '), "]"),
            debug_group = 'debug'
        )
        rn <- rownames(prjs)
        missing_names <- which(is.na(rn) | rn == "")
        # Assign a name to each missing position
        rn [missing_names] <- paste0("dim_", missing_names-1)
        log_print(
            paste0("process_prjs_object | rn [", paste(rn, collapse = ', '), "]"),
            debug_group = 'debug'
        )
        # Reassign names to dataframe 
        rownames(prjs) <-rn
        paste0("process_prjs_object | Rownames after [", paste(rownames(prjs), collapse = ', '), "]")
        #log_print(head(prjs), debug_group = 'debug')
        prjs
    })

    embedding_ids <- reactive({
        log_print("--> embedding idx", debug_group = 'debug')
        bp_indices <- NULL
        log_print(paste0("length: ", length(prj_object())))
        if (length(prj_object()>0)){
            #prjs <- process_prjs_object()
            prjs <- prj_object()
            on.exit({log_print("embedding idx -->", debug_group = 'debug');})
            # Building projections selected points object
            bp <- brushedPoints(
                prjs, #Projections
                input$projections_brush, #Selected points
                allRows = TRUE
            ) 
            # Check rownames for debugging errors. Comment when fixed (the 'if' was added to avoid this error)
            log_print("embedding_idx | ROWNAMES | ", debug_group = 'debug')
            paste0("embedding_idx | ROWNAMES | [", paste(rownames(bp), collapse = ', '), "]")
            # Get the indexes of the points within the projections point list
            bp_indices <- bp %>% rownames_to_column("index") %>% 
                dplyr::filter(selected_ == TRUE)        %>% 
                pull(index)                             %>% 
                as.integer
        }
        # Returns NULL if no point have been computed in projections
        # Returns the indexes of the points selected within the projections plot
        bp_indices
    })

    filtered_window_indices <- reactive({
        log_print("--> filtered_window_indices", debug_group = 'generic')
        on.exit(log_print("filtered_window_indices -->", debug_group = 'generic'))
        req(embedding_ids(), input$wlen != 0, input$stride != 0)
        req(length(embedding_ids()>0))
        window_indices <- get_window_indices_(embedding_ids(), input$wlen, input$stride, LOG_PATH, LOG_HEADER)
        window_indices
    })

    window_list <- reactive({
        # Get the indices of the windows related to the selected projection points
        log_print("--> window_list", debug_group = 'generic')
        on.exit(log_print("window_list -->", debug_group = 'generic'))
        reduced_window_list <- NULL
        # Get the window indices
        if (! is.null(filtered_window_indices())){
            window_indices <- filtered_window_indices()
            # Put all the indices in one list and remove duplicates
            unlist_window_indices = filtered_window_indices()
            # Calculate a vector of differences to detect idx where a new window should be created 
            diff_vector <- diff(unlist_window_indices,1)
            log_print(paste0("window list || diff ", diff_vector), debug_group = 'tmi')
            # Take indexes where the difference is greater than one (that represent a change of window)
            idx_window_limits <- which(diff_vector!=1)
            log_print(paste0("window_list || idx_window_limits", idx_window_limits), debug_group = 'tmi')
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
        }
        reduced_window_list
    })
    
    # Generate timeseries data for dygraph dygraph
    ts_plot <- reactive({
        log_print(
            paste0(
                "--> ts_plot | Before req 1 | wlen ", input$wlen, 
                " | tsdf ready? ", tsdf_ready()
            ), 
            debug_group = 'main'
        )
        req(
            input$select_variables, 
            input$wlen != 0, 
            input$stride, 
            tsdf_ready()
        )
        t_tsp_0 = Sys.time()
        on.exit({log_print("ts_plot -->", debug_group = 'main'); flush.console()})        
        log_print(paste0("ts_plot || ts variables Before ts_plot_base ", ts_variables_str(ts_variables), " -->"), debug_group = 'main')
        ts_plt = ts_plot_base() 
        log_print("ts_plot | bp", debug_group = 'main')
        log_print("ts_plot | embedings idxs ", debug_group = 'main')
        # Calculate windows if conditions are met (if embedding_idxs is !=0, that means at least 1 point is selected)
        log_print("ts_plot | Before if", debug_group = 'debug')
        if (
                ! is.null(embedding_ids())
            &&  (length(embedding_ids())!=0) 
            &&  isTRUE(input$plot_windows)
        ) {
            reduced_window_list = window_list()
            log_print(paste0("ts_plot | Selected projections ", reduced_window_list[1]), TRUE, LOG_PATH, LOG_HEADER, debug_group = 'tmi')
            start_indices = min(sapply(reduced_window_list, function(x) x[1]))
            end_indices = max(sapply(reduced_window_list, function(x) x[2]))

            log_print(paste0("ts_plot || Reduced ", reduced_window_list), debug_group = 'tmi')
            log_print(paste0("ts_plot || sd_id ", start_indices), debug_group = 'tmi')
            log_print(paste0("ts_plot || ed_id ", end_indices), debug_group = 'tmi')

            if (!is.na(start_indices) && !is.na(end_indices)) {
                view_size = end_indices-start_indices+1
                max_size = 10000

                start_date = tsdf()$timeindex[start_indices]
                end_date = tsdf()$timeindex[end_indices]
                start_date
                log_print(
                    paste0(
                        "ts_plot | reduced_window_list (", 
                        start_date, end_date, ")", 
                        "view size ", view_size, 
                        "max size ", max_size
                    ),
                    debug_group = 'debug'
                )
                if (view_size > max_size) {
                    end_date = tsdf()$timeindex[start_indices + max_size - 1]
                    #range_color = "#FF0000" # Red
                } 
            
                range_color = "#CCEBD6" # Original
            

                # # Plot the windows
                count = 0
                for(ts_idxs in reduced_window_list) {
                    count = count + 1
                    log_print(paste0("idxs", ts_idxs), debug_group = 'tmi')
                    start_event_date = tsdf()$timeindex[head(ts_idxs, 1)]
                    end_event_date = tsdf()$timeindex[tail(ts_idxs, 1)]
                    log_print(paste0("start_event_date", start_event_date), debug_group = 'debug')
                    log_print(paste0("end_event_date", end_event_date), debug_group = 'debug')
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
                log_print(
                    paste0(
                        "-- Error obtaining selected projection points start_id ", start_indices, 
                        "| end_id ", end_indices
                    ),
                    debug_group = 'error'
                )
            }
        } else { 
            log_print(
                paste0(
                    "ts_plot | Else | ",
                    " is null ids? ", is.null(embedding_ids()),
                    " embedding_ids~",length(embedding_ids()), 
                    " | plot windows ?", 
                    input$plot_windows 
                ),
                debug_group = 'debug'
            )
        }
        t_tsp_1 = Sys.time()
        log_print(paste0("ts plot | Execution time: ", t_tsp_1 - t_tsp_0), debug_group = 'main')
        log_print(paste0("ts plot | is null ts_plt ? ", is.null(ts_plt)), debug_group = 'main')
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
    
    output$enc_info = renderDataTable({
        selected_encoder_name <- req(input$encoder)
        on.exit({log_print("Encoder artiffact -->", debug_group = 'main'); flush.console()})
        log_print(paste0("--> Encoder artiffact", selected_encoder_name), debug_group = 'main')
        selected_encoder <- encs_l[[selected_encoder_name]]
        encoder_metadata <- req(selected_encoder$metadata)
        log_print(paste0("Encoder artiffact | encoder metadata ", selected_encoder_name), debug_group = 'debug')
        encoder_metadata %>%enframe()
            })
    
    # Generate time series info table
    output$ts_ar_info = renderDataTable({
        log_print("--> ts_ar_info", debug_group = 'debug')
        on.exit(log_print("ts_ar_info -->"), debug_group = 'debug')
        log_print(ts_ar_config())
        ts_ar_config() %>% enframe()
    })
    
    ggplot_base <- function(prjs_, config_style, ranges, cluster){
        log_print("--> ggplot_base", debug_group = 'debug')
        log_print("ggplot_base -->", debug_group = 'debug')
        plt <- ggplot(data = prjs_) + 
            aes(
                x       = xcoord, 
                y       = ycoord, 
                fill    = highlight, 
                color = as.factor(cluster)
            ) + 
            scale_colour_manual(
                name = "clusters", 
                values = req(update_palette())
            ) +
            geom_point(
                shape = 21, 
                alpha = config_style$point_alpha, 
                size = config_style$point_size,
                stroke = 2
            ) + 
            scale_shape(solid = FALSE) +
            guides() + 
            scale_fill_manual(values = c("TRUE" = "green", "FALSE" = "black")) + #black -> NA puesto como black para el paper para ganar nitidez en los puntos
            #coord_cartesian(xlim = ranges$x, ylim = ranges$y, expand = TRUE) +
            coord_fixed(ratio = as.numeric(input$pp_ratio), xlim = ranges$x, ylim = ranges$y, expand = TRUE, clip = "on") + # Añadido para asegurar la relación de aspecto
            theme_void() + 
            theme(legend.position = "none") 
            
        return(plt)
    }

    projections_plot_comp <- reactive({
        plt <- NULL
        on.exit(
            "projections_plot_comp --> || is null plt? ", 
            is.null(plt)
        )
        log_print(
            paste0(
                " projections_plot_comp || Before req",
                " | tsdf_ready? ",  tsdf_ready(),
                " | tsdf_ready preprocessed? ",  tsdf_ready_preprocessed(),
                " | update embs? ", allow_update_embs(),
                " | enc_input_path? ", ifelse(
                    is.null(enc_input_path()), "", enc_input_path()),
                " | enc_input_ready? ", enc_input_ready(),
                " | play prjs? ", play_prjs(),
                " | play? ", play()
            ),
            debug_group = 'force'
        )
        req( 
            input$dataset,
            input$encoder,
            input$wlen != 0,
            input$stride != 0,
            tsdf_ready(),
            tsdf_ready_preprocessed(),
            input$dr_method,
            allow_update_embs(),
            clustering_options$selected,
            enc_input_path(),
            enc_input_ready(),
            play_prjs(),
            play()
        )
        log_print("--> projections_plot_comp", debug_group = 'force')
        embs_comp_or_cached()
        log_print(
            paste0("projections_plot_comp | embs? ", !is.null(embs())),
            debug_group = 'force'
        )
        req(embs)
        complete_cases <-embs_complete_cases_comp()
        log_print(
            paste0("projections_plot_comp | complete_cases? ", !is.null(complete_cases)),
            debug_group = 'force'
        )
        req(complete_cases)
        embs_complete_cases(complete_cases)
        log_print(
            paste0("projections_plot_comp | embs complete?", !is.null(embs_complete_cases())),
            debug_group = 'force'
        )
        req(embs_complete_cases())
        plt <- NULL
        
        log_print(paste0(" projections_plot_comp || ts_variables:  ", ts_variables_str(ts_variables)), debug_group = 'force')
        t_pp_0 <- Sys.time()
        projections()
        prjs_ <- req(prjs())
        log_print(
            paste0(" projections_plot_comp || before highlight ", "prjs_" %dimstr% prjs_),
            debug_group = 'debug'
        )
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
        log_print(
            paste0(
                " projections_plot_comp || Cluster ", 
                "prjs_" %dimstr% prjs_
            ),debug_group = 'debug'
        )
        if(!("cluster" %in% names(prjs_))){prjs_$cluster = FALSE}
        log_print(paste0("projections_plot_comp | GoGo Plot! ", nrow(prjs_)), debug_group = 'debug')
        plt <- ggplot_base(prjs_, config_style, ranges, cluster)
        
        if (input$show_lines){
            plt <- plt + geom_path(linewidth=config_style$path_line_size, colour = "#2F3B65",alpha = config_style$path_alpha)
        }

        observeEvent(input$savePlot, {
            plt <- plt + theme(plot.background = element_rect(fill = "white"))
            ggsave(filename = set_prjs_plot_name(), plot = plt, path = "../data/plots/")
        })

        t_pp_1 = Sys.time()
        log_print(paste0("projections_plot_comp | Projections Plot time: ", t_pp_1-t_pp_0), TRUE, LOG_PATH, LOG_HEADER, debug_group = 'force')
        temp_log <<- log_add(
            log_mssg                = temp_log, 
            function_               = "Projections Plot",
            cpu_flag                = input$cpu_flag,
            dr_method               = input$dr_method,
            clustering_options      = input$clustering_options,
            zoom                    = input$zoom_btn,
            time                    = t_pp_1-t_pp_0, 
            mssg                    = paste0("R execution time | Ts selected point", input$ts_plot_dygraph_click)
        )
        plt
    })

    # Generate projections plot
    output$projections_plot <- renderPlot({
        req(play_prjs())
        on.exit({log_print("output$projections_plot -->", debug_group='main')})
        log_print("--> output$projections_plot")
        plt <- projections_plot_comp()
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
        req(input$ts_plot_dygraph_click$x_closest_point,tsdf_ready())
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
            log_print(
                paste0(
                    "ts_plot_dygraph || Before req", 
                    "| tsdf ?", !is.null(tsdf()),
                    "| prj_object? ",  !is.null(prj_object()),
                    "| play ?", play(),
                    "| embs ?", play_prjs()
                ),
                debug_group = 'debug'
            )
            req (
                input$encoder,
                input$wlen   != 0, 
                input$stride != 0,
                tsdf(),
                input$select_variables,
                prj_object(),
                play(),
                play_prjs()
            )
            log_print("**** ts_plot_dygraph ****", debug_group = 'force')
            tspd_0 = Sys.time()
            log_print(paste0("ts_plot_dygraph || ts_variables before ts_plot ", ts_variables_str(ts_variables)), debug_group = 'force')
            ts_plot <- ts_plot()
            log_print(paste0("ts_plot_dygraph || ts_plot computed"), debug_group = 'force')
            #ts_plot %>% dyAxis("x", axisLabelFormatter = format_time_with_index) %>% JS(js_plot_with_id)
            ts_plot %>% dyCallbacks(drawCallback = JS(js_plot_with_id))
            log_print(paste0("ts_plot_dygraph || After callbacks"), debug_group = 'force')
            tspd_1 = Sys.time()
            time <- tspd_1 - tspd_0
            log_print(
                mssg = paste0("ts_plot dygraph | Execution_time: ", time),
                file_flag = TRUE, 
                file_path = LOG_PATH, 
                log_header = LOG_HEADER, 
                debug_group ='force'
            )
            ts_plot
        }   
    )

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
            log_print(paste0("| JS PLOT RENDER | ", mssg), TRUE, LOG_PATH, LOG_HEADER, debug_group = 'js')
            temp_log <<- log_add(
                log_mssg                = temp_log,
                function_               = paste0("JS Plot Render ", plot_id),
                cpu_flag                = input$cpu_flag,
                dr_method               = input$dr_method,
                clustering_options      = input$clustering_options,
                zoom                    = input$zoom_btn,
                time                    = last_time/1000,   
                mssg                    = paste0(plot_id, " renderization time (secs)")
            )
        } 
    })

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
    
    observeEvent(input$tabs, {
      if (input$tabs == "MPlot") {
            mplot_start_computation(TRUE)
            log_print(
                paste0(
                    "mplot_start_computation |", 
                    mplot_start_computation(),
                     " | ", 
                    input$tabs
                ),
                debug_group = 'main'
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
                    "mplot_start_computation |", mplot_start_computation(),
                    " | ", input$tabs
                ), debug_group = 'main'
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

    observeEvent(input$play_embs, {
        on.exit( 
            log_print(
                paste0("Play embs || Changes to ", allow_update_embs()),  
                debug_group = 'react'
            ))
        # Update vars
        play_prjs(! play_prjs())
        allow_update_embs(play_prjs())
        log_print(paste0("Play embs || Change button ", allow_update_embs()),  debug_group = 'react')
        # Update buttons
        enable_disable_embs()
        # Compute projections if it is the case
        if (play_prjs() && play()){
            log_print("play_embs set to true, recompute projections_plot ", debug_group = 'react')
            projections_plot_comp()
        }
    })

    output$proposed_section_sizes <- renderText({
        paste0("Proposed section sizes: [", paste(proposed_section_sizes(), collapse = ', '), "]")
    })

    output$proposed_wlen <- renderText({
        paste0("Proposed window sizes: [", paste(proposed_wlen(), collapse = ', '), "]")
    })

})
