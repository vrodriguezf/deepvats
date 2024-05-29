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
  if ( is.null(sim_matrix$dominant_lens)){
    #Poner slider si se quiere o fijar un valor con sentido
    sim_matrix$MP_AB$provide_lens(nlens = 5, print_flag = TRUE)
    sim_matrix$dominant_lens = sim_matrix$MP_AB$dominant_lens
  }
  return(sim_matrix$dominant_lens)
}

mplot_variable_selector <- function(id){
  ns <- NS(id)
  fluidRow(
    dropdownButton(
      tags$b("Select a variable"),
      tags$div(
        style = 'height:200px; overflow-y: scroll',
        radioButtons(
          inputId   = ns("select_variable"),
          label     = NULL,
          choices   = list("No variables available" = ""),
          selected  = NULL
        )
      ),
      circle = FALSE, status = "primary", size = "xs",
      icon = icon("gear"), width = "300px",
      tooltip = tooltipOptions(title = "Select the variable"),
      inputId = ns("mplot_variable_selector")
    )
  )
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
        fluidRow(
          column(4, mplot_variable_selector(id)),
          column(8)
          )
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
    if(total_points > 0 && ( ! is.null(input[[ns("select_variable")]]))){
      selected_variable <- input[[ns("select_variable")]]
      sim_matrix <- similarity_matrix(data()[selected_variable], input2$wlen)
      log_print("Similarity matrix initialized")     
      tryCatch({
        log_print(paste0("SM data_b: ", length(sim_matrix$data_b)))
        ## Añadir los parámetros faltantes como sliders
        sim_matrix$compute(
          mp_method           = 'stump',
          dm_method           = 'stump',
          print_flag          = TRUE,
          debug               = TRUE,
          time_flag           = TRUE,
          allow_experimental  = TRUE,
          ensure_symetric     = FALSE,
          ### Poner selector a esto para que se pueda variar en el dygraph
          c_min               = 0, 
          c_max               = total_points,
          r_min               = 0,
          r_max               = total_points,
          ################################################################
          max_points          = input$maxPoints,
          subsequence_len     = input2$wlen,
          provide_len         = FALSE,
          downsample_flag     = TRUE,
          min_lag             = 8, #Añadir selector
          print_depth         = 1,
          threads             = 1, # Añadir selector en caso de scamp
          gpus                = {} # Añadir selector en caso de scamp que dependa de las gpus realmente disponibles
        )
        ## 
        log_print("Similarity matrix computed")
      }, error = function(e){
        log_print(paste0("Error computing similarity matrix: ", e$message))
      })

      flens <- fourierLens(sim_matrix)
      log_print("Fourier lens computed")
      output$fourierLensOutput <- renderText({
        paste0("Proposed lengths:", flens)
      })
    }
  })
}

# Función del módulo
mplot_tabServer <- function(id, tsdf, input2) {
  moduleServer(
    id, 
    function(input, output, session){
      debug_plot_flag(id, input, output, session)
      mplot_compute(id, input, output, session, tsdf, input2)
      observeEvent(tsdf(), {
        data <- tsdf()
        if (!is.null(data)) {
          ns <- NS(id)
          updateRadioButtons(
            session, 
            ns("select_variable"),
            choices = colnames(data),
            selected = colnames(data)[1])
          }
        })
    }
  )
  
}

