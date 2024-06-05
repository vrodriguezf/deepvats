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
similarity_matrix <- function(tsa, wlen) {
  sim_matrix <- mplots$MatrixProfilePlot(
    DM_AB           = mplots$DistanceMatrix(),
    MP_AB           = mplots$MatrixProfile(),
    data            = tsa,
    data_b          = tsa,
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
  inputId <- ns("mplot_variable")
  selectInput(
    inputId   = inputId,
    label     = "Select a variable",
    choices   = list("No variables available" = ""),
    selected  = ""
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
          column(4, actionBttn(
            inputId = ns("mplot_compute_flag"), 
            label = "Activate/Deactivate Compute MPlot", 
            style = "bordered", 
            color = "primary", 
            size = "sm", 
            block = TRUE)
          ),
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
mplot_compute <- function(
  id, 
  input, 
  output, 
  session, 
  data, 
  input_caller_2,
  mplot_compute_allow,
  mplot_compute_allow_inside
){
  ns <- NS(id)

  variableInputId <- ns("mplot_variable")

  observeEvent(
    list(
      data(), 
      input_caller_2$wlen, 
      input$maxPoints, 
      input_caller_2[[ variableInputId ]],
      input_caller_2[[ ns("mplot_compute_flag") ]]
    ),
  {

    log_print(paste0(" [ MPlot Compute ] MPlot Compute Allow ", mplot_compute_allow_inside(), "\n"))

    req(
      data(), 
      input_caller_2$wlen, 
      input$maxPoints, 
      input_caller_2[[ variableInputId ]],
      mplot_compute_allow() == TRUE
    )
    

    

    log_print(paste0(" [ MPlot Compute ]", "\n",
      " [ MPlot Compute ] wlen ", input_caller_2$wlen, "\n",
      " [ MPlot Compute ] maxPoints ", input$maxPoints, "\n",
      " [ MPlot Compute ] inputId ", variableInputId, "\n",
      " [ MPlot Compute ] MPlot Compute Allow ", mplot_compute_allow(), "\n"
    ))
    
    if(! is.null(input_caller_2[[ variableInputId ]])){
      
      selected_variable <- input_caller_2[[ variableInputId ]]
      
      log_print(paste0(" [ MPlot Compute ] Selected variable: ", selected_variable, "\n"))

      #variable_data <- data()$selected_variable
      
      variable_data <- data()[[selected_variable]]
      
      total_points <- length(variable_data)
      
      req(total_points > 0)

      log_print(
        paste0(
          "[ MPlot Compute ] ", "\n", 
          "[ MPlot Compute ] Data ~ ", dim(data()), "\n",
          "[ MPlot Compute ] total_points ", total_points, "\n",
          #"[ MPlot Compute ] Data ", data(), "\n",
          "[ MPlot Compute ] Selected data[ ", selected_variable, " ] ~ ", length(variable_data), "\n"
        )
      )     

      sim_matrix <- similarity_matrix(variable_data, input_caller_2$wlen)
      
      log_print("Similarity matrix initialized")     
      
      tryCatch({
        log_print(paste0("SM data_b: ", dim(sim_matrix$data_b)))
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
          subsequence_len     = input_caller_2$wlen,
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

      flens <- {1}

      tryCatch({
        flens <- fourierLens(sim_matrix)
        log_print("Fourier lens computed")
      }, error = function(e){
        log_print(paste0("Error computing fourier lens: ", e$message))
      })
      
      output$fourierLensOutput <- renderText({
        paste0("Proposed lengths:", flens)
      })
    }
  })
}



# Función del módulo
mplot_tabServer <- function(
  id, tsdf, mplot_compute_allow, input_caller, output_caller, session_caller, start_computation
) {
  moduleServer(
    id, 
    function(input, output, session){
      ns <- session$ns

      debug_plot_flag(id, input, output, session)
      
      mp_ts_variables <- reactiveValues(selected = NULL)
      
      variableInputId <- ns("mplot_variable") 

      observeEvent(tsdf(), {  

        freezeReactiveValue(input, variableInputId)
        
        data <- isolate(tsdf())
        
        if (!is.null(data)) {
          log_print(paste0(" [ MPlot_tabServer ]", "\n", 
          " [ MPlot_tab Server ] inputID ", variableInputId, "\n"))

          mp_ts_variables$selected = names(data)[names(data) != "timeindex"]
          updateSelectInput(
            session   = session_caller, 
            inputId   = variableInputId,
            choices   = mp_ts_variables$selected,
            selected  = mp_ts_variables$selected[1]
          )
        }
      })
      
      ## Checking the input level of the selected variable
      observeEvent( input_caller [[ variableInputId ]], {
        mplot_compute_allow(TRUE)
        log_print(paste0("[ MPlot_tab Server ]", "\n",
          "[ MPlot_tab Server ] Variable changed: ", input_caller[[ variableInputId ]], "\n"
          ))
      })

      mplot_compute_allow_inside <- reactiveVal(TRUE)

      observeEvent( input_caller [[ ns("mplot_compute_flag") ]] , {
        log_print(
          paste0(
            "mplot_compute_flag changed to: ", 
            input_caller [[ ns("mplot_compute_flag") ]]
          )
        )
        if (input_caller [[ ns("mplot_compute_flag") ]] ){
          mplot_compute_allow(TRUE)
          mplot_compute_allow_inside(TRUE)
          log_print(paste0("mplot_compute_allow changed to: ", mplot_compute_allow()))
        } else {
          mplot_compute_allow(FALSE)
          mplot_compute_allow_inside(FALSE)
        }
      })

      mplot_compute(id, input, output, session, tsdf, input_caller, mplot_compute_allow, mplot_compute_allow_inside)
    }
  )
}

