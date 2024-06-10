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
    subsequence_len = as.integer(wlen),
    self_join       = FALSE
  )
  return ( sim_matrix )
}

matrix_profile <- function(data, MP_AB) {
  index <- data$timeindex[1:dim(MP_AB$distances)[1]]
  distances <- do.call(rbind, MP_AB$distances)
  mp_xts <- xts( distances, order.by = index)
  return ( mp_xts )
}

mplot <- function(data, wlen, DM_AB) {
  index <- data$timeindex
  dm_xts <- xts( DM_AB$distances, order.by = index )
  return ( dm_xts )
}



fourierLens <- function(sim_matrix) {
  if ( is.null(sim_matrix$dominant_lens)){
    #Poner slider si se quiere o fijar un valor con sentido
    sim_matrix$MP_AB$provide_lens(nlens = as.integer(5), print_flag = TRUE)
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
          column(6,matrix_profile_plot_switch(id)),
          column(6,matrix_profile_plot_max_points_slider(id)),
          column(6,textOutput(ns("fourierLensOutput")))
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
          )
        ),
          fluidRow(
            column(8, tags$h3("Matrix Profile"), dygraphOutput(ns("matrix_profile_plot"), height = "100") %>% withSpinner()),
            column(8, tags$h3("MPlot"), uiOutput(ns("mplot_plot"), height = "300") %>% withSpinner()),
            column(8,tags$h3("TA (horizontal axis)"), dygraphOutput(ns("tsA_plot"), height = "100") %>% withSpinner()),
            column(8, tags$h3("TB (vertical axis)"), dygraphOutput(ns("tsB_plot"), height = "100") %>% withSpinner())
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
    ns <- NS(id)
    dygraph(data) %>% dyOptions(
        stepPlot = TRUE,
        title = "MPlot"
    )
}


matrix_profile_dygraph <- function(id, data){
    ns <- NS(id)
    dygraph(data) %>% dyOptions(
        stepPlot = TRUE,
        title = "Matrix Profile Plot"
    )
}

tsA_data_plot <- function(id, data){
  #TODO: usando como "plantilla" ts_plot_dygraph aquí hay que pintar la parte visible de tsA marcando como "ventana" la correspondiente del MPlot (COLUMNA)
  ns <- NS(id)
  dygraphOutput(data) %>% dyOptions(
    stepPlot = TRUE,
    title = "Time Series A"
  )
}

tsB_data_plot <- function(id, data){
  #TODO: usando como "plantilla" ts_plot_dygraph aquí hay que pintar la parte visible de tsA marcando como "ventana" la correspondiente del MPlot (FILA)
  ns <- NS(id)
  dygraphOutput(sim_matrix$data) %>% dyOptions(
    stepPlot = TRUE,
    title = "Time Series B"
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
          "[ MPlot Compute 0] ", "\n", 
          "[ MPlot Compute 0] Data ~ ", dim(data()), "\n",
          "[ MPlot Compute 0] total_points ", total_points, "\n",
          #"[ MPlot Compute 0] Data ", data(), "\n",
          "[ MPlot Compute 0] Selected data[ ", selected_variable, " ] ~ ", length(variable_data), "\n",
          "[ MPlot Compute 0] wlen ", input_caller_2$wlen, "\n"
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
          c_min               = as.integer(0), 
          c_max               = as.integer(total_points),
          r_min               = as.integer(0),
          r_max               = as.integer(total_points),
          ################################################################
          max_points          = as.integer(input$maxPoints),
          subsequence_len     = as.integer(input_caller_2$wlen),
          provide_len         = FALSE,
          downsample_flag     = TRUE,
          min_lag             = as.integer(8), #Añadir selector
          print_depth         = as.integer(1),
          threads             = as.integer(1), # Añadir selector en caso de scamp
          gpus                = {} # Añadir selector en caso de scamp que dependa de las gpus realmente disponibles
        )
        ## 
        log_print("Similarity matrix computed")
        #log_print(paste0("Similarity matrix: ", sim_matrix$DM_AB$data))
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
        paste0("Proposed lengths:", paste(flens, collapse = ", "))
      })

      output$matrix_profile_plot <- renderDygraph({
        matrix_profile_dygraph(id, matrix_profile(data(), sim_matrix$MP_AB))
      })

      output$mplot_plot <- renderUI({
         plotOutput(
                "mplot_plot", 
                click = "mplot_click",
                height = "600px"
            ) %>% withSpinner()
      })

      output$projections_plot <- renderPlot({
        req(sim_matrix$MP_AB$distances)
        distances_matrix <- sim_matrix$MP_AB$distances
        inices1 <- data()$timeindex[1:dim(distances_matrix)[1]]
        indices2 <- data()$timeindex[1:dim(distances_matrix)[2]]

        dist_df <- melt(distances_matrix)
        dist_df$Var1 <- indices1
        dist_df$Var2 <- indices2
        ggplot(dist_df, aes(x = Var1, y = Var2, fill = value)) +
        geom_tile() +
        scale_fill_gradient(low = "white", high = "blue") +
        labs(x = "Index", y = "Index", fill = "Distance") +
        theme_minimal()
      })

    ts_base <- function(selected_data, min_date, max_date, axis){
        log_print("--> ts_plot_base")
        t_ts_plot_0 <- Sys.time()
        index <- data()$timeindex

        if(is.numeric(index)) {
          log_print("****** !!!!!!!!!! Index was numeric. We need dates. The first date is 1/1/1970 !!!!!!!!!!!*****")
          index <- as.POSIXct(index, origin = "1970-01-01")
        }

        if (is.numeric(min_date)) { min_date   <- as.POSIXct(min_date, origin = "1970-01-01") }
        if (is.numeric(max_date)) { max_date   <- as.POSIXct(max_date, origin = "1970-01-01") }
    

        #index <- data$timeindex[1:dim(MP_AB$distances)[axis]] #1 A, 2 B
        ts_xts <- xts(selected_data, order.by = index)
        t_ts_plot_1 <- Sys.time()
        log_print(paste0("ts_plot_base | tsdf_xts time", t_ts_plot_1-t_ts_plot_0)) 
        
        
        
        log_print(paste("Type of index:", class(index)))
        log_print(paste("Type of min:", class(min_date), " | ",  min_date))
        log_print(paste("Type of max:", class(max_date), " | ", max_date))
        log_print(paste("Selected data dimensions:", dim(ts_xts)))
        log_print(paste("Index dimensions:", length(index)))
        
        ts_plt = dygraph(
            ts_xts,
            width="100%", height = "400px"
        ) %>% 
        dyRangeSelector(c(min_date, max_date)) %>% 
        dyHighlight(hideOnMouseOut = TRUE) %>%
        dyOptions(labelsUTC = FALSE  ) %>%
        dyCrosshair(direction = "vertical")%>%
        dyLegend(show = "follow", hideOnMouseOut = TRUE) %>%
        dyUnzoom() %>%
        dyHighlight(highlightSeriesOpts = list(strokeWidth = 3)) %>%
        dyCSS(
            textConnection(
                ".dygraph-legend > span { display: none; }
                .dygraph-legend > span.highlight { display: inline; }"
            )
        ) 

    }



    tsA_plot_ <- reactive({#Aqui minDate y maxDate deberían ser el minimo y el maximo cogidos para el eje x de la matriz
        log_print("--> tsA_plot | Before req 1")
        t_tsp_0 = Sys.time()
        on.exit({log_print("ts_plot -->"); flush.console()})

        req(isolate(data()))
        min_date <- data()$timeindex[2]
        #log_print(paste0("timeindex", data()$timeindex))
        log_print(paste0("min_date", min_date))
        idmax <- min(input$maxPoints, length(variable_data)-1)
        max_date <- data()$timeindex[idmax]
        ts_plt = ts_base(variable_data, min_date, total_points, max_date)   
        ts_plt <- ts_plt %>% dyRangeSelector(c(min_date, max_date))
         
        t_tsp_1 = Sys.time()
        log_print(paste0("ts plot | Execution time: ", t_tsp_1 - t_tsp_0))
        ts_plt
    })
      
    output$tsA_plot <- renderDygraph(
        {
            log_print("**** tsA_plot dygraph ****")
            tspd_0 = Sys.time()
            tsA_plot_ <- req(tsA_plot_())
            tspd_1 = Sys.time()
            log_print(paste0("TSA_plot time: ", tspd_1 - tspd_0, " seconds"))
            tsA_plot_
        }   
    )

    tsB_plot_ <- reactive({#Aqui minDate y maxDate deberían ser el minimo y el maximo cogidos para el eje y de la matriz
        log_print("--> tsB_plot | Before req 1")
        t_tsp_0 = Sys.time()
        on.exit({log_print("tsB_plot -->"); flush.console()})

        req(isolate(data()))
        min_date <- data()$timeindex[2]
        #log_print(paste0("timeindex", data()$timeindex))
        log_print(paste0("min_date", min_date))
        idmax <- min(input$maxPoints, length(variable_data)-1)
        max_date <- data()$timeindex[idmax]
        ts_plt = ts_base(variable_data, min_date, total_points, max_date)   
        ts_plt <- ts_plt %>% dyRangeSelector(c(min_date, max_date))
         
        t_tsp_1 = Sys.time()
        log_print(paste0("tsB plot | Execution time: ", t_tsp_1 - t_tsp_0))
        ts_plt
    })
      
    output$tsB_plot <- renderDygraph(
        {
            log_print("**** tsB_plot dygraph ****")
            tspd_0 = Sys.time()
            tsB_plot_ <- req(tsB_plot_())
            tspd_1 = Sys.time()
            log_print(paste0("TSB_plot time: ", tspd_1 - tspd_0, " seconds"))
            tsB_plot_
        }   
    )

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
          mplot_compute_allow(start_computation())
          mplot_compute_allow_inside(start_computation())
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

