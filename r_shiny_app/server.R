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

    
    ###
    # Inputs
    ###
    observe({
        req(exists("runs"))
        updateSelectInput(session=session,
                          inputId = "run_dr",
                          choices = names(runs))
    })
    
    ###
    # Reactives
    ###
    
    # Selected run is the run_dr
    selected_run = reactive({
        req(exists("runs"))
        runs[[input$run_dr]]
    })
    
    run_dr_config = reactive({
        req(selected_run())
        fromJSON(selected_run()$json_config)
    })
    
    run_dcae_config = reactive({
        req(run_dr_config())
        dcae_run_path = run_dr_config()$dcae_run_path$value
        dcae_run = api$run(dcae_run_path)
        fromJSON(dcae_run$json_config)
    })
    
    ts_ar_config = reactive({
        req(selected_run())
        used_arts = selected_run()$used_artifacts()
        # Creo lista vacia y añado a los metadatos el nombre.
        # used_arts = mi_run$used_artifacts()
        # Take the first item of the iterable (that is the used by the software)
        artifact = iter_next(used_arts)
        list_used_arts = artifact$metadata$TS
        list_used_arts$name = artifact$name
        list_used_arts$aliases = artifact$aliases
        list_used_arts$artifact_name = artifact$artifact_name
        list_used_arts$id = artifact$id
        list_used_arts$created_at = artifact$created_at
        list_used_arts
    })
    
    embs_ar_config = reactive({
        req(selected_run())
        logged_arts = selected_run()$logged_artifacts()
        # Take the first item of the iterable (that is the used by the software)
        artifact = iter_next(logged_arts)
        list_used_arts = artifact$metadata$ref
        list_used_arts$name = artifact$name
        list_used_arts$aliases = artifact$aliases
        list_used_arts$artifact_name = artifact$artifact_name
        list_used_arts$id = artifact$id
        list_used_arts$created_at = artifact$created_at
        list_used_arts
    })
    
    w = reactive({run_dcae_config()$w$value})
    
    s = reactive({run_dcae_config()$stride$value})
    
    emb_object <- reactive({
        req(selected_run())
        logged_artifacts = selected_run()$logged_artifacts()
        # NOTE: This assumes the run has only logged the embeddings artifacts, so it is located in the first position
        embs_ar = iter_next(logged_artifacts)
        embs <- py_load_object(filename = file.path(DEFAULT_PATH_WANDB_ARTIFACTS, embs_ar$metadata$ref$hash)) %>% as.data.frame
        colnames(embs) = c("xcoord", "ycoord")
        embs
    })
    
    
    
    
    # Reactive when show_clusters is clicked or when update_clust button is clicked (i.e. after changing the parameter minPts)
    embeddings <- reactive({
        req(selected_run(),emb_object())
        embs <- emb_object()
        # embs2 <<-  slice(embs, input$points_emb[1]:input$points_emb[2])
        # Calculate clusters when checkbox is clicked (TRUE)
        # if(input$show_clusters){
        #     cl2 <- hdbscan$HDBSCAN(min_cluster_size = as.integer(input$min_cluster_size_hdbscan),
        #                            min_samples=as.integer(input$min_samples_hdbscan),
        #                            cluster_selection_epsilon =input$cluster_selection_epsilon_hdbscan,
        #                            metric = input$metric_hdbscan)$fit(embs)
        #     embs$cluster <- cl2$labels_
        #     # IF the value "-1" exists, assign the first element of mycolors to #000000, if not, assign the normal colorRampPalette
        #     myColors <<-append("#000000",colorRampPalette(brewer.pal(12,"Paired"))(length(unique(embs$cluster))-1))
        #     
        # }
        # print(nrow(embs2))
        embs
    })
    
    clustering_event <- eventReactive(c(input$show_clusters, input$update_clust),{
        
    })
    
    tsdf <- reactive({
        req(selected_run())
        used_artifacts <- selected_run()$used_artifacts()
        # NOTE: This assumes the run has only used the tsdf artifact, so it is located in the first position
        ts_ar = iter_next(used_artifacts)
        # Take the first and last element of the timeseries corresponding to the subset of the embedding selectedx
        # first_data_index <- get_window_indices(idxs = input$points_emb[1], w = w(), s = s())[[1]] %>% head(1)
        last_data_index <- get_window_indices(idxs = nrow(embeddings()), w = w(), s = s())[[1]] %>% tail(1)
        tsdf <- py_load_object(filename = file.path(DEFAULT_PATH_WANDB_ARTIFACTS, ts_ar$metadata$TS$hash)) %>% 
            rownames_to_column("timeindex") %>% 
            slice(1:last_data_index) %>% 
            # slice(first_data_index:last_data_index) %>% 
            column_to_rownames(var = "timeindex")
    })
    
    # auxiliary object for the interaction ts->embeddings
    tsidxs_per_embedding_idx <- reactive({
        get_window_indices(1:nrow(embeddings()), w=w(), s=s())
        # get_window_indices(input$points_emb[1]:input$points_emb[2], w=w(), s=s())
    })
    
    
    make_individual_dygraph <- function(i){
        plt <- dygraph(tsdf()[i],height= "170",group = "timeseries", ylab = names(tsdf())[i],width="100%") %>%
            dySeries(color=color_scale_dygraph[i]) %>%
            dyHighlight(hideOnMouseOut = TRUE) %>%
            dyOptions(labelsUTC = TRUE) %>%
            dyLegend(show = "follow", hideOnMouseOut = TRUE) %>%
            dyUnzoom() %>%
            dyHighlight(highlightSeriesOpts = list(strokeWidth = 3)) %>%
            dyCSS(
                textConnection(
                    "
                        .dygraph-ylabel {font-size: 9px; width: 80%;text-align: center;float: right} 
                        .dygraph-legend > span { display: none; }
                        .dygraph-legend > span.highlight { display: inline; }"
                )
            )
        if(i==1){
            plt <-plt %>%
                dyRangeSelector(height = 20, strokeColor = "")
        }
        plt
    }
    
    ts_plot <- reactive({
        req(tsdf(), embeddings())
        datos <<- tsdf()
        embs_prueba <<- embeddings()
        col_names_tsdf <<- setNames(names(datos), names(datos))
        # If dygraph_sel is TRUE, show individual dygraphs.
        if(input$dygraph_sel){
            # TODO
        }else{
            ts_plt <- dygraph(datos %>% select(input$select_variables), width="100%", height = "400px") %>%
                        dyRangeSelector() %>%
                        dyHighlight(hideOnMouseOut = TRUE) %>%
                        dyOptions(labelsUTC = TRUE) %>%
                        dyCrosshair(direction = "vertical")%>%
                        dyLegend(show = "follow", hideOnMouseOut = TRUE) %>%
                        dyUnzoom() %>%
                        dyHighlight(highlightSeriesOpts = list(strokeWidth = 3)) %>%
                        dyCSS(
                            textConnection(
                                "
                            .dygraph-legend > span { display: none; }
                            .dygraph-legend > span.highlight { display: inline; }"
                            )
                        )
            # SACAR EL IF DEL REACTIVE PARA AL MODIFICAR EL BRUSH NO SE REPLOTEE TODO
            #  Al sacarlo hay que quitar los rectángulos previos.
            if (!is.null(input$embeddings_brush)) {
                bp <<- brushedPoints(embeddings(), input$embeddings_brush, allRows = TRUE)
                embedding_idxs <<- bp %>% rownames_to_column("index") %>% dplyr::filter(selected_ == TRUE) %>% pull(index) %>% as.integer
                
                for(ts_idxs in get_window_indices(embedding_idxs, w(), s())) {
                    ts_plt <- ts_plt %>% dyShading(from = rownames(tsdf())[head(ts_idxs, 1)],
                                             to = rownames(tsdf())[tail(ts_idxs, 1)],
                                             color = "red")
                }
                
                
                # rects<-get_window_indices(embedding_idxs, w(), s())
                # num_rects <- length(rects)
                # rects_ini <- vector(mode = "list", length = num_rects)
                # rects_fin <- vector(mode = "list", length = num_rects)
                # for(i in 1:num_rects) {
                #     rects_ini[[i]] <- head(rects[[i]],1)
                #     rects_fin[[i]] <- tail(rects[[i]],1)
                # }
                # 
                # ts_plt <- vec_dyShading(ts_plt,rects_ini, rects_fin,"red",rownames(datos))

            }
        }
        ts_plt
    })
    
    
    # Observe the events related to zoom the embedding graph:
    ranges <- reactiveValues(x = NULL, y = NULL)
    observeEvent(input$embeddings_dblclick,{
        brush <- input$embeddings_brush
        if (!is.null(brush)) {
            ranges$x <- c(brush$xmin, brush$xmax)
            ranges$y <- c(brush$ymin, brush$ymax)
            
        } else {
            ranges$x <- NULL
            ranges$y <- NULL
        }
    })
    
    # Observe the events related to change the appearance of the embedding graph:
    config_style <- reactiveValues(path_line_size = 0.08,
                                   path_alpha = 5/10,
                                   point_alpha = 1/10,
                                   point_size = 1)
    
    observeEvent(input$update_emb_graph,{
        style_values <- list(path_line_size = input$path_line_size ,
                             path_alpha = input$path_alpha,
                             point_alpha = input$point_alpha,
                             point_size = input$point_size )
        
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
    
    # Reactive emb_plot
    emb_plot <- reactive({
        req(embeddings())
        embs_ <- embeddings()
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
    ###
    # Outputs
    ###
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
    
    output$embeddings_plot <- renderPlot({emb_plot()})
    
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
        # brush <- input$embeddings_brush
        # if (!is.null(brush)) {
        #     ranges$x <- NULL
        #     ranges$y <- NULL
        # }
        ts_plot()
    })
    
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
    
    
    

    
    output$points_emb_controls <- renderUI({
        req(selected_run(),emb_object())
        embs <- emb_object()
        max_value <- nrow(embs)
        sliderInput("points_emb", "Select range of points to plot in the embedding", min = 1, max = max_value,value = c(0,2000), ticks = FALSE)
    })
    
    output$embeddings_plot_ui <- renderUI({
        plotOutput("embeddings_plot", 
                   click = "embeddings_click",
                   brush = "embeddings_brush",
                   dblclick = "embeddings_dblclick",
                   height = input$embedding_plot_height) %>% withSpinner()
    })
    
})
