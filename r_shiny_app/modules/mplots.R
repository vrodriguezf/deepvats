#--- UI ---#
matrix_profile_plot_switch <- function(id){
  ns <- NS(id)
  materialSwitch(
    inputId  = ns("matrix_profile_flag"),  # Usando ns() para el ID
    label    = "Plot Matrix Profile",
    status   = "info",
    value    = TRUE,
    inline   = TRUE
  )
}

mplot_tabUI <- function(id) {
  ns <- NS(id)
  tabPanel(
    "MPlot",
    fluidRow(
        h3("MPlot | Similarity Matrix Plot"),
        column(
            8,
            matrix_profile_plot_switch(id)
        ),
        column(3)
    ),
    fluidRow(
        column(8)
    ),

    
  )

}

#--- SERVER ---#

debug_plot_flag <- function(id, input, output, session){
    ns <- NS(id)
    observeEvent(input$matrix_profile_flag, {
        print(
            paste0(
                "matrix_profile_flag changed: ", 
                input$matrix_profile_flag
            )
        )
    })
    
}

# Función del módulo
mplot_tabServer <- function(id) {
  moduleServer(
    id, 
    function(input, output, session){
        debug_plot_flag(id, input, output, session)
    }
  )
  
}
