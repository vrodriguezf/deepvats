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
    
    w = reactive({run_dcae_config()$w$value})
    
    s = reactive({run_dcae_config()$stride$value})
    
    # Reactive when show_clusters is clicked or when update_clust button is clicked (i.e. after changing the parameter minPts)
    embeddings <- eventReactive(c(input$show_clusters, input$update_clust),{
        req(selected_run())
        logged_artifacts = selected_run()$logged_artifacts()
        # NOTE: This assumes the run has only logged the embeddings artifacts, so it is located in the first position
        embs_ar = iter_next(logged_artifacts)
        embs <- py_load_object(filename = file.path(DEFAULT_PATH_WANDB_ARTIFACTS, embs_ar$metadata$ref$hash)) %>% as.data.frame
        colnames(embs) = c("xcoord", "ycoord")
        # Calculate clusters when checkbox is clicked (TRUE)
        if(input$show_clusters){
            cl2 <- hdbscan(embs, minPts = input$minPts_hdbscan)
            embs$cluster <- cl2$cluster
        }
        embs
    })
    
    tsdf <- reactive({
        req(selected_run())
        used_artifacts = selected_run()$used_artifacts()
        # NOTE: This assumes the run has only used the tsdf artifact, so it is located in the first position
        ts_ar = iter_next(used_artifacts)
        last_data_index = get_window_indices(idxs = nrow(embeddings()), w = w(), s = s())[[1]] %>% tail(1)
        tsdf = py_load_object(filename = file.path(DEFAULT_PATH_WANDB_ARTIFACTS, ts_ar$metadata$TS$hash)) %>% 
            rownames_to_column("timeindex") %>% 
            slice(1:last_data_index) %>% 
            column_to_rownames(var = "timeindex")
    })
    
    # auxiliary object for the interaction ts->embeddings
    tsidxs_per_embedding_idx <- reactive({
        get_window_indices(1:nrow(embeddings()), w=w(), s=s())
    })
    
    ts_plot <- reactive({
        req(tsdf(), embeddings())
        plt <- dygraph(tsdf(), main = "Original data (normalized)") %>%
            dyRangeSelector() %>%
            dyHighlight(hideOnMouseOut = TRUE) %>%
            dyOptions(labelsUTC = TRUE) %>%
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
        
        if (!is.null(input$embeddings_brush)) {
            bp = brushedPoints(embeddings(), input$embeddings_brush, allRows = TRUE)
            embedding_idxs = bp %>% rownames_to_column("index") %>% dplyr::filter(selected_ == TRUE) %>% pull(index) %>% as.integer
            for(ts_idxs in get_window_indices(embedding_idxs, w(), s())) {
                plt <- plt %>% dyShading(from = rownames(tsdf())[head(ts_idxs, 1)], 
                                         to = rownames(tsdf())[tail(ts_idxs, 1)],
                                         color = "#CCEBD6")
            }
            # plt <- plt %>% dyShading(from = rownames(tsdf)[1], 
            #                          to = rownames(tsdf)[100],
            #                          color = "#CCEBD6")
            # get_window_indices(embedding_idxs, w=w, s=s) %>% 
            #     walk(function(ts_idxs) {
            #         print(paste0("from: ", rownames(tsdf)[head(ts_idxs, 1)], "\nto: ", rownames(tsdf)[tail(ts_idxs, 1)]))
            #         plt <- plt %>% dyShading(from = rownames(tsdf)[head(ts_idxs, 1)], 
            #                                  to = rownames(tsdf)[tail(ts_idxs, 1)],
            #                                  color = "#CCEBD6")
            #     })
        }
        
        plt
    })
    
    # Observe the events related to zoom the embedding graph:
    ranges <- reactiveValues(x = NULL, y = NULL)
    observeEvent(input$update_coord_graph,{
        # Take input values
        zoom_values <- list(xmin = input$x_min,
                            xmax = input$x_max,
                            ymin = input$y_min,
                            ymax = input$y_max)
        if (!is.null(zoom_values)) {
            ranges$x <- c(zoom_values$xmin, zoom_values$xmax)
            ranges$y <- c(zoom_values$ymin, zoom_values$ymax)
            
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
        }

        plt <- ggplot(data = embs_) + 
            aes(x = xcoord, y = ycoord, fill = highlight, color = cluster) + 
            geom_point(shape = 21,alpha = config_style$point_alpha, size = config_style$point_size) + 
            scale_shape(solid = FALSE) +
            geom_path(size=config_style$path_line_size, colour = "#2F3B65",alpha = config_style$path_alpha) + 
            guides() + 
            scale_fill_manual(values = c("TRUE" = "green", "FALSE" = "NA"))+
            coord_cartesian(xlim = ranges$x, ylim = ranges$y, expand = TRUE)+
            theme(legend.position = "none",
                  panel.background = element_rect(fill = "white", colour = "black"))
        
        plt
        # svgPanZoom(
        #     svglite:::inlineSVG(
        #         #will put on separate line but also need show
        #         show(
        #             plt
        #         )
        #     )
        # )
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
        
        
        
        #Brushed points
        # bp = brushedPoints(embeddings, input$embeddings_brush, allRows = TRUE)
        # #indices = embeddings[which(embeddings$xcoord == bp$xcoord & embeddings$ycoord == bp$ycoord),] %>% rownames() %>% as.integer
        # indices = bp %>% rownames_to_column("index") %>%  dplyr::filter(selected_ == TRUE) %>% pull(index) %>% as.integer
        # print(bp$selected_ %>% any)
        # print(indices)
        
        paste0(
            "click: ", xy_str(input$embeddings_click),
            "brush: ", xy_range_str(input$embeddings_brush)
        )
    })
    
    output$ts_plot_dygraph <- renderDygraph({ts_plot()})
})
