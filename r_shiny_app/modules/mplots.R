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
matrix_profile_plot_max_points_slider <- function(id){
  ns <- NS(id)
  sliderInput(
    ns("maxPoints"), 
    "Select max number of points to plot", 
    min   = 10000, 
    max   = 100000, 
    value = 10000, 
    step  = 1000
  )
}
similarity_matrix <- function(data, wlen) {
  sim_matrix <- mplots$MatrixProfilePlot(
    DM_AB           = mplots$DistanceMatrix(),
    MP_AB           = mplots$MatrixProfile(),
    data            = data(),
    data_b          = data(),
    subsequence_len = wlen,
    self_join       = FALSE
  )
  return(sim_matrix)
}

fourierLens <- function(sim_matrix) {
  if ( sim_matrix$dominant_lens == NULL){
    #Poner slider si se quiere o fijar un valor con sentido
    sim_matrix$MP_AB$provide_lens(nlens = 5)
    sim_matrix$dominant_lens = sim_matrix$MP_AB$dominant_lens
  }
  return(sim_matrix$dominant_lens)
}

mplot_tabUI <- function(id) {
  ns <- NS(id)
  tabPanel(
      "MPlot",
      fluidRow(
        h3("MPlot | Similarity Matrix Plot"),
        fluidRow(
          column(4,matrix_profile_plot_switch(id)),
          column(6,matrix_profile_plot_max_points_slider(id)),
          column(4,textOutput(ns("fourierLensOutput")))
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
mplot_compute <- function(id, input, output, session, data, input2){
    ns <- NS(id)
    observeEvent(
      list(data(), input2$wlen, input$maxPoints),
    {
      req(data(), input2$wlen, input$maxPoints)
      total_points <- length(data())
      log_print(paste0(
        " [ MPlot Compute ] data ", total_points, "\n", 
        " [ MPlot Compute ] wlen ", input2$wlen, "\n",
        " [ MPlot Compute ] maxPoints ", input$maxPoints, "\n"
      ))
      if(total_points > 0){
        sim_matrix <- similarity_matrix(data, input2$wlen)
        log_print("Similarity matrix initialized")     
        if ( length(sim_matrix$DM_AB$distances) > 0 ) {
          flens <- fourierLens(sim_matrix)
          log_print("Fourier lens computed")
          output$fourierLensOutput <- renderText({
            paste0("Proposed lengths:", flens)
          })
        }
      }
    }
  )
}

# Función del módulo
mplot_tabServer <- function(id, tsdf, input2) {
  moduleServer(
    id, 
    function(input, output, session){
      debug_plot_flag(id, input, output, session)
      mplot_compute(id, input, output, session, tsdf, input2)
    }
  )
  
}

