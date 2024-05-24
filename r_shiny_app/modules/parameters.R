select_datasetUI <- function(id){
    selectizeInput("dataset", label = "Dataset", choices = NULL)
}


select_dataset <- function(encs_l, input, output, session){
    observeEvent(input$dataset, {
        #req(encs_l)
        log_print("--> observeEvent input_dataset | update encoder list")
        log_print(input$dataset)
        freezeReactiveValue(input, "encoder")
        log_print(paste0("observeEvent input_dataset | update encoders for dataset ", input$dataset))
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
            {log_print("observeEvent input_dataset | update encoder list -->"); flush.console()}
        )
    }, label = "input_encoder")    
}