loadUI <- function(id) {
    ns <- NS(id)
    tagList(
        fluidRow(
        shiny::actionButton("load_dataset", label = "Load dataset", icon = icon("database")),
        shiny::actionButton("load_embs", label = "Load embeddings", icon = icon("project-diagram"))
      ),
    )
}

load <- function(input, output, session) {
    #--- Añadir el código de Ángel aquí ---#
    observeEvent(input$load_dataset, {
        log_print("Loading dataset", debug_level = 1, debug_group = 'main')
    })
    observeEvent(input$load_embs, {
        log_print("Loading embeddings", debug_level = 1, debug_group = 'main')
    })
}