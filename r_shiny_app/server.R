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
    
    observe({
        req(exists("runs"))
        updateSelectInput(session=session,
                          inputId = "run_dr",
                          choices = names(runs))
    })
    
    selected_run = reactive({
        req(exists("runs"))
        runs[[input$run_dr]]
    })
    
    ###
    # Outputs
    ###
    output$run_dr_info_title = renderText({
        req(selected_run())
        tags$h3(paste0("Configuration of run ", selected_run()$id, " (", selected_run()$name, ")"))
    })
    
    output$run_dr_info = renderDataTable({
        req(selected_run())
        fromJSON(selected_run()$json_config) %>%
            map(~ .$value) %>%
            enframe()
    })
    
    output$embeddings_plot <- renderPlot({
        ggplot(data = embeddings) + aes(x = xcoord, y = ycoord) + geom_point() + geom_path()
    })

    output$click_info <- renderText({
        paste0("x=", input$embeddings_click$x, "\ny=", input$embeddings_click$y)
    })
    
    output$ts_plot <- renderPlot({
        req(input$embeddings_click)
        point = nearPoints(embeddings, input$embeddings_click, threshold = 10, maxpoints = 1)
        print(point)
        index = embeddings[which(embeddings$x == point$x & embeddings$y == point$y),] %>% rownames() %>% as.integer
        window_df = tsdf %>% slice(get_window_indices(index, w, s)) %>% pivot_longer(-Time)
        ggplot(data=window_df, aes(x=Time, y=value)) + 
            facet_wrap(~name, ncol=1) + geom_line()    
    })
})
