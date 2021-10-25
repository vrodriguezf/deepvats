#
# This is the server logic of a Shiny web application. You can run the
# application by clicking 'Run App' above.
#
# Find out more about building applications with Shiny here:
#
#    http://shiny.rstudio.com/
#


shinyServer(function(input, output, session) {

    
    ######################
    #  REACTIVES VALUES  #
    ######################
    
    # Reactive values created to update the current range of the main slider input
    slider_range <- reactiveValues(min_value = 1, max_value = 2)
    
    
    # Reactive value created to keep updated the selected precomputed clusters_labels artifact
    precomputed_clusters <- reactiveValues(selected = NULL)
    
    
    # Reactive value created to keep updated the selected clustering option
    clustering_options <- reactiveValues(selected = "no_clusters")
    
    
    # Reactive value created to configure the graph brush
    ranges <- reactiveValues(x = NULL, y = NULL)
    
    
    # Reactive value created to configure clusters options
    clusters_config <- reactiveValues(metric_hdbscan = DEFAULT_VALUES$metric_hdbscan,
                                      min_cluster_size_hdbscan = DEFAULT_VALUES$min_cluster_size_hdbscan,
                                      min_samples_hdbscan = DEFAULT_VALUES$min_samples_hdbscan,
                                      cluster_selection_epsilon_hdbscan = DEFAULT_VALUES$cluster_selection_epsilon_hdbscan)
    
    
    # Reactive values created to configure the appearance of the embeddings graph.
    config_style <- reactiveValues(path_line_size = DEFAULT_VALUES$path_line_size,
                                   path_alpha = DEFAULT_VALUES$path_alpha,
                                   point_alpha = DEFAULT_VALUES$point_alpha,
                                   point_size = DEFAULT_VALUES$point_size)
    
    
    # Reactive value created to store time series selected variables
    ts_variables <- reactiveValues(selected = NULL)
    
    
    
    #################################
    #  OBSERVERS & OBSERVERS EVENTS #
    #################################
    
    # Update "run_dr" selectInput when the app is loaded
    observe({
        req(exists("runs"))
        updateSelectInput(session = session,
                          inputId = "run_dr",
                          choices = names(runs))
    })
    
    
    # Update "metric_hdbscan" selectInput when the app is loaded
    observe({
        updateSelectInput(session = session,
                          inputId = "metric_hdbscan",
                          choices = names(req(hdbscan_metrics)))
    })
    

    # Update global config when input$run_dr is changed
    observeEvent(input$run_dr, {
        # Get the embeddings number of points and update the sliderInput
        embs <- req(emb_object())
        slider_range$min_value <- as.integer(1)
        slider_range$max_value <- as.integer(nrow(embs))
        updateSliderInput(session = session, inputId = "points_emb",
                          min = slider_range$min_value, max = slider_range$max_value,
                          value = c(slider_range$min_value, slider_range$max_value))
        
        # Update precomputed clusters_labels artifacts list
        clusters_ar_names <- names(req(clusters_artifacts()))
        precomputed_clusters$selected <- if (length(clusters_ar_names) == 0) NULL else clusters_ar_names[1]
        updateSelectInput(session = session, 
                          inputId = "clusters_labels_name",
                          choices = clusters_ar_names, 
                          selected = precomputed_clusters$selected)
        
        # Enable/disable "precomputed_clusters" option depending on clusters_ar_names length
        shinyjs::toggleState(selector = "[type=radio][value=precomputed_clusters]", 
                             condition = length(clusters_ar_names) > 0)

        # Update clustering option, by default "no_clusters"
        clustering_options$selected <- "no_clusters"
        reset("clustering_options")
        
        # Update cluster parameters to default values and update interface config
        clusters_config$metric_hdbscan <- DEFAULT_VALUES$metric_hdbscan
        reset("metric_hdbscan")
        clusters_config$min_cluster_size_hdbscan <- DEFAULT_VALUES$min_cluster_size_hdbscan
        reset("min_cluster_size_hdbscan")
        clusters_config$min_samples_hdbscan <- DEFAULT_VALUES$min_samples_hdbscan
        reset("min_samples_hdbscan")
        clusters_config$cluster_selection_epsilon_hdbscan <- DEFAULT_VALUES$cluster_selection_epsilon_hdbscan
        reset("cluster_selection_epsilon_hdbscan")
        
        # Update selected time series variables and update interface config
        ts_variables$selected <- names(req(tsdf()))
        updateCheckboxGroupInput(session = session,
                                 inputId = "select_variables",
                                 choices = ts_variables$selected,
                                 selected = ts_variables$selected)
    })
    
    
    # Update slider_range reactive values with current samples range
    observe({
        req(input$points_emb)
        slider_range$min_value <- input$points_emb[1]
        slider_range$max_value <- input$points_emb[2]
    })
    
    
    # Update precomputed_clusters reactive value when the input changes
    observe({
        precomputed_clusters$selected <- req(input$clusters_labels_name)
    })
    
    
    # Update clustering_options reactive value when the input changes
    observe({
        clustering_options$selected <- req(input$clustering_options)
    })

    
    # Update clusters_config reactive values when user clicks on "calculate_clusters" button
    observeEvent(input$calculate_clusters, {
        clusters_config$metric_hdbscan <- req(input$metric_hdbscan)
        clusters_config$min_cluster_size_hdbscan <- req(input$min_cluster_size_hdbscan)
        clusters_config$min_samples_hdbscan <- req(input$min_samples_hdbscan)
        clusters_config$cluster_selection_epsilon_hdbscan <- req(input$cluster_selection_epsilon_hdbscan)
    })
    
    
    # Observe the events related to zoom the embeddings graph
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
    
    
    # Observe the events related to change the appearance of the embeddings graph
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
    
    
    # Update ts_variables reactive value when time series variable selection changes
    observeEvent(input$select_variables, {
        ts_variables$selected <- input$select_variables
    })
    
    
    # Observe to check/uncheck all variables
    observeEvent(input$selectall,{
        ts_variables$selected <- names(req(tsdf()))
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
    
    # Get selected dimensionality-reduction run in "run_dr" selectInput
    selected_run = reactive({
        req(exists("runs"))
        print(runs[[input$run_dr]])
        runs[[input$run_dr]]
    })
    
    
    # Get dimensionality reduction (dr) run metadata
    run_dr_config = reactive({
        fromJSON(req(selected_run())$json_config)
    })
    
    
    # Get dcae run metadata
    run_enc_config = reactive({
        run_dr_cfg <- req(run_dr_config())
        enc_run_path = ifelse(!is.null(run_dr_cfg$enc_run_path), 
                              run_dr_cfg$enc_run_path$value, 
                              run_dr_cfg$dcae_run_path$value) # TODO: Deprecate, this is here for compatibility with old runs!
        enc_run = api$run(enc_run_path)
        fromJSON(enc_run$json_config)
    })
    
    
    # Get windows size value
    w = reactive({
        req(run_enc_config())$w$value
    })
    
    
    # Get stride value
    s = reactive({
        req(run_enc_config())$stride$value
    })
    
    
    # Get the dataset artifact that has been used to train the encoder
    dr_artifact <- reactive({
        used_arts_it <- req(selected_run())$used_artifacts()
        used_arts <- iterate(used_arts_it)
        # If only one dataset artifact has been used, it's assumed that this has been used to create the embedding space
        # Otherwise, what to do?? TODO
        if (length(used_arts) != 1) {
            used_arts <- used_arts %>% purrr::keep(~ .$type == "dataset")
        }
        used_arts[[1]]
    })
    
    
    # Get timeseries artifact metadata
    ts_ar_config = reactive({
        dr_ar <- req(dr_artifact())
        print(dr_ar$name)
        list_used_arts = dr_ar$metadata$TS
        list_used_arts$vars = dr_ar$metadata$TS$vars %>% stringr::str_c(collapse = "; ")
        list_used_arts$name = dr_ar$name
        list_used_arts$aliases = dr_ar$aliases
        list_used_arts$artifact_name = dr_ar$name
        list_used_arts$id = dr_ar$id
        list_used_arts$created_at = dr_ar$created_at
        list_used_arts
    })
    
    
    # Get logged artifacts 
    logged_artifacts <- reactive({
        logged_arts_it <- req(selected_run())$logged_artifacts()
        logged_arts <- iterate(logged_arts_it)
        logged_arts %>% set_names(logged_arts %>% map(~.$name))
    })
    
    # Get embedding artifact
    embs_artifact <- reactive({
        logged_arts <- req(logged_artifacts())
        emb_ar <- logged_arts %>% purrr::keep(stringr::str_detect(names(logged_arts), "^embeddings|projections"))
        emb_ar[[1]] # This assumes the run has only logged one embedding artifact 
    })
    
    
    # Get embedding artifact metadata
    embs_ar_config = reactive({
        emb_ar <- req(embs_artifact())
        list_used_arts = emb_ar$metadata$ref
        list_used_arts$name = emb_ar$name
        list_used_arts$aliases = emb_ar$aliases
        list_used_arts$artifact_name = emb_ar$name
        list_used_arts$id = emb_ar$id
        list_used_arts$created_at = emb_ar$created_at
        list_used_arts
    })
    
    
    # Get projection object (projections dataframe) from W&B
    emb_object <- reactive({
        embs_ar <- req(embs_artifact())
        embs <- py_load_object(filename = file.path(DEFAULT_PATH_WANDB_ARTIFACTS, embs_ar$metadata$ref$hash)) %>% as.data.frame
        colnames(embs) = c("xcoord", "ycoord")
        embs
    })
    
    
    # Get clusters_labels artifacts
    clusters_artifacts <- reactive({
        logged_arts <- req(logged_artifacts())
        logged_arts %>% purrr::keep(stringr::str_detect(names(logged_arts), "^clusters_labels"))
    })
    
    
    # Get selected clusters_labels artifact
    selected_clusters_labels_ar <- reactive({
        req(clusters_artifacts())[[req(precomputed_clusters$selected)]]
    })
    
    
    # Get clusters_labels artifact description
    clusters_artifact_description <- reactive({
        req(selected_clusters_labels_ar())$description
    })
    
    
    # Load and filter TimeSeries object from wandb
    tsdf <- reactive({
        dr_ar <- req(dr_artifact())
        # Take the first and last element of the timeseries corresponding to the subset of the embedding selectedx
        first_data_index <- get_window_indices(idxs = slider_range$min_value, w = w(), s = s())[[1]] %>% head(1)
        last_data_index <- get_window_indices(idxs = slider_range$max_value, w = w(), s = s())[[1]] %>% tail(1)
        py_load_object(filename = file.path(DEFAULT_PATH_WANDB_ARTIFACTS, dr_ar$metadata$TS$hash)) %>% 
            rownames_to_column("timeindex") %>% 
            slice(first_data_index:last_data_index) %>%
            column_to_rownames(var = "timeindex")
    })
    
    
    # Auxiliary object for the interaction ts->embeddings
    tsidxs_per_embedding_idx <- reactive({
        print('tsidxs_per_embedding_idx()')
        get_window_indices(1:nrow(req(embeddings())), w = w(), s = s())
    })
    
    
    # Filter the embedding points and calculate/show the clusters if conditions are met.
    embeddings <- reactive({
        print('embeddings()')
        embs <- req(emb_object()) %>% slice(slider_range$min_value:slider_range$max_value)
        switch(clustering_options$selected,
               precomputed_clusters={
                   filename <- req(selected_clusters_labels_ar())$metadata$ref$hash
                   clusters_labels <- py_load_object(filename = file.path(DEFAULT_PATH_WANDB_ARTIFACTS, filename))
                   embs$cluster <- clusters_labels[slider_range$min_value:slider_range$max_value]
               },
               calculate_clusters={
                   clusters <- hdbscan$HDBSCAN(min_cluster_size = as.integer(clusters_config$min_cluster_size_hdbscan),
                                               min_samples = as.integer(clusters_config$min_samples_hdbscan),
                                               cluster_selection_epsilon = clusters_config$cluster_selection_epsilon_hdbscan,
                                               metric = clusters_config$metric_hdbscan)$fit(embs)
                   embs$cluster <- clusters$labels_
               })
        embs
    })
    
    
    # Update the colour palette for the clusters
    update_palette <- reactive({
        print('update_palette()')
        embs <- req(embeddings())
        if ("cluster" %in% names(embs)) {
            unique_labels <- unique(embs$cluster)
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
    
    
    # Generate timeseries dygraph
    ts_plot <- reactive({
        print('ts_plot()')
        req(tsdf(), emb_object())
        tsdf_data <- tsdf()
        ts_plt <- dygraph(tsdf_data %>% select(ts_variables$selected), width="100%", height = "400px") %>%
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
    
    
    
    #############
    #  OUTPUTS  #
    #############
    
    # Generate dimensionality-reduction run title
    output$run_dr_info_title = renderUI({
        req(selected_run())
        text <- paste0("Configuration of dimensionality reduction run ", selected_run()$id, " (", selected_run()$name, ")")
        tags$h3(text)
    })
    
    
    # Generate dimensionality-reduction run info table
    output$run_dr_info = renderDataTable({
        run_dr_config() %>%
            map(~ .$value) %>%
            enframe()
    })
    
    
    # Generate DCAE info table
    output$run_enc_info = renderDataTable({
            run_enc_config() %>% 
            map(~ .$value) %>%
            enframe()
    })
    
    
    # Generate time series info table
    output$ts_ar_info = renderDataTable({
        ts_ar_config() %>% 
            enframe()
    })
    
    
    # Generate embeddings artifact info table
    output$embs_ar_info = renderDataTable({
        embs_ar_config() %>% 
            enframe()
    })
    
    
    # Render selected clusters_labels artifact description
    output$clusters_labels_ar_desc = renderText({
        req(clusters_artifact_description())
    })
    
    
    # Generate embeddings plot
    output$embeddings_plot <- renderPlot({
        print('emb_plot()')
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
        if(!("cluster" %in% names(embs_)))
            embs_$cluster = FALSE
        
        plt <- ggplot(data = embs_) + 
            aes(x = xcoord, y = ycoord, fill = highlight, color = as.factor(cluster)) + 
            scale_colour_manual(name = "clusters", values = req(update_palette())) +
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
    
    
    # Render embeddings plot
    output$embeddings_plot_ui <- renderUI({
        plotOutput("embeddings_plot", 
                   click = "embeddings_click",
                   brush = "embeddings_brush",
                   height = input$embedding_plot_height) %>% withSpinner()
    })
    
    
    # Render information about the selected point in the time series graph
    output$point <- renderText({
        ts_idx = which(ts_plot()$ts$x$data[[1]] == input$ts_plot_dygraph_click$x_closest_point)
        paste0('X = ', strftime(req(input$ts_plot_dygraph_click$x_closest_point), "%F %H:%M:%S"), 
               '; Y = ', req(input$ts_plot_dygraph_click$y_closest_point),
               '; X (raw) = ', req(input$ts_plot_dygraph_click$x_closest_point))
    })

    
    # Render information about the selected point and brush in the embeddings graph
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
    
    
    # Generate time series plot
    output$ts_plot_dygraph <- renderDygraph({
        ts_plot()
    })
    
})
