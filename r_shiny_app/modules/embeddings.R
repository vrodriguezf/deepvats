# This module defines the embeddings tab of the App.

###############
### Helpers ###
###############

# -- Embeddings aesthetics -- #

path_line_selector <- function(id){
  sliderInput(
    "path_line_size", 
    label = "path_line_size", 
    value = DEFAULT_VALUES$path_line_size, 
    min=0, max=5, step = 0.01
  )
}
path_alpha_selector <- function(id){
  sliderInput(
    "path_alpha", 
    label = "path_alpha",
    value = DEFAULT_VALUES$path_alpha, 
    min=0, max=1, step = 0.01
  )
}
point_alpha_selector <- function(id){
  sliderInput(
    "point_alpha", 
    label = "point_alpha",
    value = DEFAULT_VALUES$point_alpha, 
    min=0, max=1, step = 0.01
  )
}
point_size_selector <- function(id) {
  sliderInput(
    "point_size", 
    label = "point_size",
    value = DEFAULT_VALUES$point_size, 
    min=0, max=10, step = 0.5
  )
}

embeddings_aesthetics_update <- function(id) {
  ns <- NS(id)
  actionBttn(
    inputId = "update_prj_graph",
    label = "Update aestethics",
    style = "simple",
    color = "primary",
    icon = icon("bar-chart"),
    size = "xs", block = TRUE
  )
}

embeddings_aesthetics <- function(id){
  ns <- NS(id)
  column(1,
    dropdownButton(
      tags$b("Set height of the projections plot (px):"),
      numericInput("embedding_plot_height", label = "Height",value =400),
      hr(),
      tags$b("Configure aestethics"),
      path_line_selector("path_line_selector"),
      path_alpha_selector("path_alpha_selector"),
      point_alpha_selector("point_alpha_selector"),
      point_size_selector("point_size_selector"),
      checkboxInput("show_lines", "Show lines", value = TRUE),
      actionButton('savePlot', 'Save embedding projections plot'),
      embeddings_aesthetics_update("embeddings_aesthetics_update"),
      circle = FALSE, status = "primary",
      icon = icon("gear"), width = "300px",size = "xs",
      tooltip = tooltipOptions(title = "Configure the embedding appearance"),
      inputId = "projections_config"
    )
  )
}

#-- Time Series Plot --#

original_data_plot_controllers <- function(id){
  ns <- NS(id)
  fluidRow(
    dropdownButton(
      tags$b("Select/deselect variables"),
      tags$div(
        style = 'height:200px; overflow-y: scroll', 
        checkboxGroupInput(
          inputId   = "select_variables",
          label     = NULL, 
          choices   = NULL, 
          selected  = NULL
        )
      ),
      actionBttn(
        inputId = "selectall",
        label   = "Select/Deselect all",
        style   = "simple",
        color   = "primary",
        icon    = icon("check-double"),
        size    = "xs", 
        block   = TRUE
      ),
      hr(),
      prettySwitch(
        inputId = "dygraph_sel",
        label = "Show stacked graphs (Not available yet)",
        status = "success",fill = TRUE
      ),
      circle = FALSE, status = "primary", size = "xs",
      icon = icon("gear"), width = "300px",
      tooltip = tooltipOptions(title = "Configure the TS appearance"),
      inputId = "ts_config"
    )
  )
}
original_data_plot <- function(id){
  ns <- NS(id)
  fluidRow(
    column(12,
      dygraphOutput("ts_plot_dygraph") %>% withSpinner(),
      plotOutput("windows_plot"),
      uiOutput("windows_text")
    )
  )
}

# -- Controllers -- #
embeddings_zoom_button <- function(id){
  ns <- NS(id)
  prettyToggle(
    inputId     = "zoom_btn",
    label_on    = "Zoom out",
    label_off   = "Zoom in",
    shape       = "square",
    outline     = TRUE,
    plain       = TRUE,
    inline      = TRUE,
    icon_on     = icon("search-minus"), 
    icon_off    = icon("search-plus"),
    status_on   = "danger",
    status_off  = "primary"
  )
}

embeddings_plot_windows <- function(id){
  ns <- NS(id)
  materialSwitch(
    inputId  = "plot_windows",
    label    = "Plot windows",
    status   = "info",
    value    = TRUE,
    inline   = TRUE
  )
}

# -- Tab UI function -- #
embeddings_tabUI <- function(id) {
  ns <- NS(id)
  tabPanel(
    "Projections",
    fluidRow(
    h3("Embedding projections"),
    fluidRow(
      embeddings_aesthetics("embeddings_aesthetics"),
        column(
          8,
          embeddings_zoom_button("embeddings_zoom_button"),
          embeddings_plot_windows("embeddings_plot_windows"),
        ),
        column(3)
      ),
      fluidRow(
        uiOutput("projections_plot_ui")
      )
    ),
    fluidRow(h3("Original data")),
    original_data_plot_controllers("original_data_plot_controllers"),
    original_data_plot("original_data_plot")
    #verbatimTextOutput("projections_plot_interaction_info"),
    #verbatimTextOutput("point")
    
  )
}

embeddings_tab <- function(input, output, session) {
    
}


