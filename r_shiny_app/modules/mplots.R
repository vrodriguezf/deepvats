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

mplot_selectors <- function(id){
    ns <- NS(id)
        # loadUI("load") -> Dar aquí también la opción a cargar serie temporal
        # hr()
        br()
        sliderInput("wlen", "Select window size", min = 0, max = 0, value =0 , step = 1)
        sliderInput("maxPoints", "Select max number of points to plot", min = 0, max = 0, value = 0, step = 1)
        textOutput(ns("fourierLens"))

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
      )
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


mplot_dygraph <- function(id, data){
    #TODO: aquí hay que meter el dygraph de mplot
    ns <- NS(id)
    fluidRow(
        column(12,
            #dygraphOutput(ns("dygraph"))
            output$fourierLens <- renderText({
                #--- aqui calcular las mejores longitudes segun fourier
                paste0("Proposed lengths:", 1)
            })
        )
    )
}


tsA_data_plot <- function(id){
  #TODO: usando como "plantilla" ts_plot_dygraph aquí hay que pintar la parte visible de tsA marcando como "ventana" la correspondiente del MPlot (COLUMNA)
  ns <- NS(id)
  fluidRow(
    column(12,
      #dygraphOutput(ns("tsA_plot_dygraph")) %>% withSpinner(),
    )
  )
}

tsB_data_plot <- function(id){
  #TODO: usando como "plantilla" ts_plot_dygraph aquí hay que pintar la parte visible de tsA marcando como "ventana" la correspondiente del MPlot (FILA)
  ns <- NS(id)
  fluidRow(
    column(12,
      #dygraphOutput(ns("tsA_plot_dygraph")) %>% withSpinner(),
    )
  )
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
