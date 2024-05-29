###############################
# Parameters seLection & load #
###############################

###########
# HELPERS #
###########

# Dataset selection
select_datasetUI <- function(id){
    selectizeInput(
        "dataset", label = "Dataset", choices = NULL
    )
}

select_datasetServer <- function(
    encs_l, input, output, session
){
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


# Dataset load
load_datasetUI <- function(id) {
    ns <- NS(id)
    tagList(
        fluidRow(
        shiny::actionButton(
            ns("load_dataset"), 
            label = "Load dataset", 
            icon = icon("database")
        ),
        shiny::actionButton(
            ns("load_embs"), 
            label = "Load embeddings", 
            icon = icon("project-diagram")
        )
      ),
    )
}

load_datasetActionDebug <-function(input, output, session){
    observeEvent(
        input$load_dataset,
    {
        log_print("Loading dataset", debug_level = 1, debug_group = 'main')
    })
            
    observeEvent(
    input$load_embs,
    {
        log_print("Loading embeddings", debug_level = 1, debug_group = 'main')
    })
}

load_datasetAction <- function(input, output, session){
    #En esta función hay que meter el código de ángel para cargar datasets & embeddings
    #Estructurar en funciones según se vaya utilizando para poder asegurar una correcta
    #ejecución y depuración en caso de bloqueos de reactividades.
}

load_datasetServer <- function(id) {
    #Lo que sean funciones de cargar & descargar, en lib/load.R 
    #Lo que sean llamadas básicas, usar load_dataset_action / load_embeddings_action
    moduleServer(
        id, 
        function(input, output, session){
            load_datasetActionDebug(input, output, session)
            load_datasetAction(input, output, session)
        }
    )
}

##################
# SIDEBAR PANEL #
##################

