#
# This is the server logic of a Shiny web application. You can run the
# application by clicking 'Run App' above.
#
# Find out more about building applications with Shiny here:
#
#    http://shiny.rstudio.com/
#


# Define server logic required to draw a histogram
shinyServer(function(input, output, session) {

    
    ############
    #  INPUTS  #
    ############
    
    observe({
        req(exists("runs"))
        updateSelectInput(session = session,
                          inputId = "run_dr",
                          choices = names(runs))
    })
    
    observe({
        updateSelectInput(session = session,
                          inputId = "metric_hdbscan",
                          choices = names(req(hdbscan_metrics)))
    })
    
    observeEvent(input$run_dr, {
        updateSelectInput(session = session,
                          inputId = "clusters_labels_name",
                          choices = names(req(clusters_artifacts())))
    })
    
    # clusters_labels_selected <- reactiveValues(value = "")
    # observe({
    #     clusters_labels_selected <- input$clusters_labels_name
    # })
    # observe({
    #     if (is.null(input$clusters_labels_name) || input$clusters_labels_name == '')
    #         clusters_labels_selected <- NULL
    #     else
    #         clusters_labels_selected <- input$clusters_labels_name
    # })
    
    
    
    
    ###############
    #  REACTIVES  #
    ###############
    
    # Selected run is the run_dr
    selected_run = reactive({
        req(exists("runs"))
        runs[[input$run_dr]]
    })
    
    # Get dimensionality reduction (dr) run metadata
    run_dr_config = reactive({
        fromJSON(req(selected_run())$json_config)
    })
    
    # Get dcae run metadata
    run_dcae_config = reactive({
        dcae_run_path = req(run_dr_config())$dcae_run_path$value
        dcae_run = api$run(dcae_run_path)
        fromJSON(dcae_run$json_config)
    })
    
    # Get windows size value
    w = reactive({
        req(run_dcae_config())$w$value
    })
    
    # Get stride value
    s = reactive({
        req(run_dcae_config())$stride$value
    })
    
    # Get the dataset artifact that has been used to construct the embedding space
    dr_artifact <- reactive({
        used_arts_it <- req(selected_run())$used_artifacts()
        used_arts <- purrr::rerun(QUERY_RUNS_LIMIT, iter_next(used_arts_it)) %>% compact()
        # If only one artifact has been used, it's assumed that this has been used to create the embedding space
        # Otherwise, the artifact that has no normalization metadata is used.
        if (length(used_arts) != 1) {
            used_arts <- used_arts %>% purrr::keep(~is.null(.$metadata$TS$normalization))
        }
        used_arts[[1]]
    })
    
    # Get timeseries artifact metadata
    ts_ar_config = reactive({
        dr_ar <- req(dr_artifact())
        list_used_arts = dr_ar$metadata$TS
        list_used_arts$vars = dr_ar$metadata$TS$vars %>% stringr::str_c(collapse = "; ")
        list_used_arts$name = dr_ar$name
        list_used_arts$aliases = dr_ar$aliases
        list_used_arts$artifact_name = dr_ar$artifact_name
        list_used_arts$id = dr_ar$id
        list_used_arts$created_at = dr_ar$created_at
        list_used_arts
    })
    
    # Get logged artifacts 
    logged_artifacts <- reactive({
        logged_arts_it <- req(selected_run())$logged_artifacts()
        logged_arts <- purrr::rerun(QUERY_RUNS_LIMIT, iter_next(logged_arts_it)) %>% compact()
        logged_arts %>% set_names(logged_arts %>% map(~.$name))
    })
    
    # Get embedding artifact
    embs_artifact <- reactive({
        logged_arts <- req(logged_artifacts())
        emb_ar <- logged_arts %>% purrr::keep(stringr::str_detect(names(logged_arts), "^embeddings"))
        emb_ar[[1]] # This assumes the run has only logged one embedding artifact 
    })
    
    # Get embedding artifact metadata
    embs_ar_config = reactive({
        emb_ar <- req(embs_artifact())
        list_used_arts = emb_ar$metadata$ref
        list_used_arts$name = emb_ar$name
        list_used_arts$aliases = emb_ar$aliases
        list_used_arts$artifact_name = emb_ar$artifact_name
        list_used_arts$id = emb_ar$id
        list_used_arts$created_at = emb_ar$created_at
        list_used_arts
    })
    
    # Get embedding object (embeddings dataframe) from W&B
    emb_object <- reactive({
        print('Ejecutando emb_object()')
        embs_ar <- req(embs_artifact())
        embs <- py_load_object(filename = file.path(DEFAULT_PATH_WANDB_ARTIFACTS, embs_ar$metadata$ref$hash)) %>% as.data.frame
        colnames(embs) = c("xcoord", "ycoord")
        embs
    })
    
    # Get clusters_labels artifacts
    clusters_artifacts <- reactive({
        print('Ejecutando clusters_artifacts()')
        logged_arts <- req(logged_artifacts())
        logged_arts %>% purrr::keep(stringr::str_detect(names(logged_arts), "^clusters_labels"))
    })
    
    # Get selected clusters_labels artifact
    selected_clusters_labels_ar <- reactive({
        req(clusters_artifacts())[[req(input$clusters_labels_name)]]
    })
    
    # Get clusters_labels artifact description
    clusters_artifact_description <- reactive({
        req(selected_clusters_labels_ar())$description
    })
    
    # Load and filter TimeSeries object from wandb
    tsdf <- reactive({
        print('Ejecutando tsdf()')
        dr_ar <<- req(dr_artifact())
        # Take the first and last element of the timeseries corresponding to the subset of the embedding selectedx
        first_data_index <- get_window_indices(idxs = input$points_emb[1], w = w(), s = s())[[1]] %>% head(1)
        last_data_index <- get_window_indices(idxs =input$points_emb[2], w = w(), s = s())[[1]] %>% tail(1)
        tsdf <- py_load_object(filename = file.path(DEFAULT_PATH_WANDB_ARTIFACTS, dr_ar$metadata$TS$hash)) %>% 
            rownames_to_column("timeindex") %>% 
            slice(first_data_index:last_data_index) %>%
            column_to_rownames(var = "timeindex")
        col_names_tsdf <<- setNames(names(tsdf), names(tsdf))
        tsdf
    })
    
    # Auxiliary object for the interaction ts->embeddings
    tsidxs_per_embedding_idx <- reactive({
        print('Ejecutando tsidxs_per_embedding_idx()')
        get_window_indices(1:nrow(req(embeddings())), w = w(), s = s())
    })
    
    # Filter the embedding points and calculate/show the clusters if conditions are met.
    embeddings <- reactive({
        print('Ejecutando embeddings()')
        embs <- req(emb_object()) %>% slice(input$points_emb[1]:input$points_emb[2])
        switch(input$cluster_options,
               precomputed_clusters={
                   filename <- req(selected_clusters_labels_ar())$metadata$ref$hash
                   clusters_labels <- py_load_object(filename = file.path(DEFAULT_PATH_WANDB_ARTIFACTS, filename))
                   embs$cluster <- clusters_labels[input$points_emb[1]:input$points_emb[2]]
                   myColors <<- append("#000000", colorRampPalette(brewer.pal(12,"Paired"))(length(unique(embs$cluster))-1))
               },
               calculate_clusters={
                   clusters <- hdbscan$HDBSCAN(min_cluster_size = as.integer(clusters_config$min_cluster_size_hdbscan),
                                               min_samples = as.integer(clusters_config$min_samples_hdbscan),
                                               cluster_selection_epsilon = clusters_config$cluster_selection_epsilon_hdbscan,
                                               metric = clusters_config$metric_hdbscan)$fit(embs)
                   embs$cluster <- clusters$labels_
                   myColors <<- append("#000000", colorRampPalette(brewer.pal(12,"Paired"))(length(unique(embs$cluster))-1))
               })
        embs
    })
    
    
    # update_palette <- reactive({
    #     embs <- req(embeddings)
    #     ## IF the value "-1" exists, assign the first element of mycolors to #000000, if not, assign the normal colorRampPalette
    #     append("#000000", colorRampPalette(brewer.pal(12,"Paired"))(length(unique(embs$cluster))-1))
    # })
    
    
    
    # PLOT GENERATION: Generate timeseries dygraph
    ts_plot <- reactive({
        print('Ejecutando ts_plot()')
        req(tsdf(), emb_object())
        tsdf_data <- tsdf()
        ts_plt <- dygraph(tsdf_data %>% select(input$select_variables), width="100%", height = "400px") %>%
                    dyRangeSelector() %>%
                    dyHighlight(hideOnMouseOut = TRUE) %>%
                    dyOptions(labelsUTC = FALSE ) %>%
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
        
        bp <- brushedPoints(emb_object(), input$embeddings_brush, allRows = TRUE)
        embedding_idxs <- bp %>% rownames_to_column("index") %>% dplyr::filter(selected_ == TRUE) %>% pull(index) %>% as.integer
        # Calculate windows if conditions are met (if embedding_idxs is !=0, that means at least 1 point is selected)
        if ((length(embedding_idxs)!=0) & isTRUE(input$plot_windows)) {
            # Get the window indices
            window_indices <- get_window_indices(embedding_idxs, w(), s())
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
                ts_plt <- ts_plt %>% dyShading(from = rownames(tsdf_data)[head(ts_idxs, 1)],
                                         to = rownames(tsdf_data)[tail(ts_idxs, 1)],
                                         color = "#CCEBD6")
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
    
    
    # PLOT CONFIGURATION EVENTS: Observe the events related to zoom the embeddings graph:
    ranges <- reactiveValues(x = NULL, y = NULL)
    observeEvent(input$zoom_btn,{
        brush <- input$embeddings_brush
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
    
    # PLOT CONFIGURATION EVENTS:  Observe the events related to change the appearance of the embeddings graph:
    config_style <- reactiveValues(path_line_size = DEFAULT_VALUES$path_line_size,
                                   path_alpha = DEFAULT_VALUES$path_alpha,
                                   point_alpha = DEFAULT_VALUES$point_alpha,
                                   point_size = DEFAULT_VALUES$point_size)
    
    observeEvent(input$update_emb_graph,{
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
    
    # CLUSTERS EVENTS:  Observe the events related to calculate clusters:
    clusters_config <- reactiveValues(metric_hdbscan = DEFAULT_VALUES$metric_hdbscan,
                                      min_cluster_size_hdbscan = DEFAULT_VALUES$min_cluster_size_hdbscan,
                                      min_samples_hdbscan = DEFAULT_VALUES$min_samples_hdbscan,
                                      cluster_selection_epsilon_hdbscan = DEFAULT_VALUES$cluster_selection_epsilon_hdbscan)
    
    observeEvent(input$calculate_clusters, {
        clusters_config$metric_hdbscan <- req(input$metric_hdbscan)
        clusters_config$min_cluster_size_hdbscan <- req(input$min_cluster_size_hdbscan)
        clusters_config$min_samples_hdbscan <- req(input$min_samples_hdbscan)
        clusters_config$cluster_selection_epsilon_hdbscan <- req(input$cluster_selection_epsilon_hdbscan)
    })
    
    
    
    #############
    #  OUTPUTS  #
    #############
    
    output$run_dr_info_title = renderUI({
        req(selected_run())
        id = selected_run()$id
        name =selected_run()$name
        foo = paste0("Configuration of dimensionality reduction run ", selected_run()$id, " (", selected_run()$name, ")")
        tags$h3(foo)
    })
    
    output$run_dr_info = renderDataTable({
        run_dr_config() %>%
            map(~ .$value) %>%
            enframe()
    })
    
    output$run_dcae_info = renderDataTable({
            run_dcae_config() %>% 
            map(~ .$value) %>%
            enframe()
    })
    
    output$ts_ar_info = renderDataTable({
        ts_ar_config() %>% 
            enframe()
    })
    
    output$embs_ar_info = renderDataTable({
        embs_ar_config() %>% 
            enframe()
    })
    
    output$clusters_labels_ar_desc = renderText({
        req(clusters_artifact_description())
    })
    
    # PLOT GENERATION: Generate embeddings plot
    output$embeddings_plot <- renderPlot({
        print('Ejecutando emb_plot()')
        embs_ <- req(embeddings())
        # Prepare the column highlight to color data
        if (!is.null(input$ts_plot_dygraph_click)) {
            selected_ts_idx = which(ts_plot()$x$data[[1]] == input$ts_plot_dygraph_click$x_closest_point)
            embeddings_idxs = tsidxs_per_embedding_idx() %>% map_lgl(~ selected_ts_idx %in% .)
            embs_$highlight = embeddings_idxs
        } else {
            embs_$highlight = FALSE
        }
        # Prepare the column highlight to color data. If input$generate_cluster has not been clicked
        # the column cluster will not exist in the dataframe, so we create with the value FALSE
        if(!("cluster" %in% names(embs_))){
            embs_$cluster = FALSE
            myColors <-"red"
        }
        
        plt <- ggplot(data = embs_) + 
            aes(x = xcoord, y = ycoord, fill = highlight, color = as.factor(cluster)) + 
            scale_colour_manual(name = "clusters",values = myColors) +
            geom_point(shape = 21,alpha = config_style$point_alpha, size = config_style$point_size) + 
            scale_shape(solid = FALSE) +
            geom_path(size=config_style$path_line_size, colour = "#2F3B65",alpha = config_style$path_alpha) + 
            guides() + 
            scale_fill_manual(values = c("TRUE" = "green", "FALSE" = "NA"))+
            coord_cartesian(xlim = ranges$x, ylim = ranges$y, expand = TRUE)+
            theme(legend.position = "none",
                  panel.background = element_rect(fill = "white", colour = "black"))
        plt
    })
    
    output$point <- renderText({
        ts_idx = which(ts_plot()$ts$x$data[[1]] == input$ts_plot_dygraph_click$x_closest_point)
        paste0('X = ', strftime(req(input$ts_plot_dygraph_click$x_closest_point), "%F %H:%M:%S"), 
               '; Y = ', req(input$ts_plot_dygraph_click$y_closest_point),
               '; X (raw) = ', req(input$ts_plot_dygraph_click$x_closest_point))
    })

    output$embeddings_plot_interaction_info <- renderText({
        
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
            "click: ", xy_str(input$embeddings_click),
            "brush: ", xy_range_str(input$embeddings_brush)
        )
    })
    
    output$ts_plot_dygraph <- renderDygraph({
        ts_plot()
    })
    
    output$embeddings_plot_ui <- renderUI({
        plotOutput("embeddings_plot", 
                   click = "embeddings_click",
                   brush = "embeddings_brush",
                   height = input$embedding_plot_height) %>% withSpinner()
    })
    
    
    #################################
    # OUTPUTS (renderUI components) #
    #################################
    
    # Get variable names to be shown in a checkboxGroupInput when select_variables dropdown is clicked
    output$select_variables <-renderUI({
        req(selected_run())
        tags$div(style= 'height:200px; overflow-y: scroll',
            checkboxGroupInput(
                inputId = "select_variables",
                label=NULL,
                choices = col_names_tsdf,
                selected = col_names_tsdf
                )
        )
    })
    
    # Observe to check/uncheck all variables
    observeEvent(input$selectall,{
        if(input$selectall %%2 == 0){
            updateCheckboxGroupInput(session = session, inputId = "select_variables",
                                     choices = col_names_tsdf, selected = col_names_tsdf)
        } else {
            updateCheckboxGroupInput(session = session, inputId = "select_variables",
                                     choices = col_names_tsdf, selected = NULL)
        }
        
    })
    
    # Open the dropdown button to load the series
    observeEvent(input$tabs,{
        if(input$tabs == "Embeddings"){
            toggleDropdownButton(inputId = "ts_config")
        }
    })
    
    # observeEvent(input$run_dr,{
    #     #req(tsdf(), ts_plot())
    # })
    
    # Get the embeddings number of points and generate the sliderInput
    output$points_emb_controls <- renderUI({
        req(selected_run(),emb_object())
        embs <- emb_object()
        max_value <- nrow(embs)
        sliderInput("points_emb", "Select range of points to plot in the embedding",
                    min = 1, max = max_value,value = c(0,max_value), ticks = FALSE)
    })
    

})
