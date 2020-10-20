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
    
    embeddings <- reactive({
        req(selected_run())
        logged_artifacts = selected_run()$logged_artifacts()
        # NOTE: This assumes the run has only logged the embeddings artifacts, so it is located in the first position
        embs_ar = iter_next(logged_artifacts)
        embs = py_load_object(filename = file.path(DEFAULT_PATH_WANDB_ARTIFACTS, embs_ar$metadata$ref$hash)) %>% as.data.frame
        colnames(embs) = c("xcoord", "ycoord")
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
    
    output$embeddings_plot <- renderPlot({
        req(embeddings())
        embs_ = embeddings()
        
        # highlighting
        if (!is.null(input$ts_plot_dygraph_click)) {
            selected_ts_idx = which(ts_plot()$x$data[[1]] == input$ts_plot_dygraph_click$x_closest_point)
            embeddings_idxs = tsidxs_per_embedding_idx() %>% map_lgl(~ selected_ts_idx %in% .)
            embs_$highlight = embeddings_idxs
        } else {
            embs_$highlight = FALSE
        }
        
        plt <- ggplot(data = embs_) + 
            aes(x = xcoord, y = ycoord, color = highlight) + 
            geom_point(shape = 21, colour = "#2F3B65") + 
            scale_shape(solid = FALSE) +
            geom_path(size=0.08, colour = "#2F3B65") + 
            guides() + 
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
