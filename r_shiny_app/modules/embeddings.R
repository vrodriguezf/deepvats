embeddings_tabUI <- function(id) {
    ns <- NS(id)
    tabPanel(
          "Projections",
          fluidRow(
            h3("Embedding projections"),
            fluidRow(
              column(1,
                     dropdownButton(
                       tags$b("Set height of the projections plot (px):"),
                       numericInput("embedding_plot_height", label = "Height",value =400),
                       hr(),
                       tags$b("Configure aestethics"),
                       sliderInput("path_line_size", label = "path_line_size", 
                                   value = DEFAULT_VALUES$path_line_size, min=0, max=5, step = 0.01),
                       sliderInput("path_alpha", label = "path_alpha",
                                   value = DEFAULT_VALUES$path_alpha, min=0, max=1, step = 0.01),
                       sliderInput("point_alpha", label = "point_alpha",
                                   value = DEFAULT_VALUES$point_alpha, min=0, max=1, step = 0.01),
                       sliderInput("point_size", label = "point_size",
                                   value = DEFAULT_VALUES$point_size, min=0, max=10, step = 0.5),
                       checkboxInput("show_lines", "Show lines", value = TRUE),
                       actionButton('savePlot', 'Save embedding projections plot'),

                       actionBttn(inputId = "update_prj_graph",label = "Update aestethics",style = "simple",
                                  color = "primary",icon = icon("bar-chart"),size = "xs", block = TRUE),
                       circle = FALSE, status = "primary",
                       icon = icon("gear"), width = "300px",size = "xs",
                       tooltip = tooltipOptions(title = "Configure the embedding appearance"),
                       inputId = "projections_config"
                     )
              ),
              column(8,
                     prettyToggle(
                       inputId = "zoom_btn",
                       label_on = "Zoom out",
                       label_off = "Zoom in",
                       shape = "square",
                       outline = TRUE,
                       plain = TRUE,
                       inline = TRUE,
                       icon_on = icon("search-minus"), 
                       icon_off = icon("search-plus"),
                       status_on = "danger",
                       status_off = "primary"
                     ),
                     materialSwitch(
                       inputId = "plot_windows",
                       label = "Plot windows",
                       status = "info",
                       value = TRUE,
                       inline = TRUE
                     )
              ),
              column(3)
            ),
            fluidRow(
              uiOutput("projections_plot_ui")
            )
          ),
          fluidRow(h3("Original data")),
          fluidRow(
            dropdownButton(
              tags$b("Select/deselect variables"),
              tags$div(style= 'height:200px; overflow-y: scroll', 
                       checkboxGroupInput(inputId = "select_variables",
                                          label=NULL, choices = NULL, selected = NULL)
              ),
              actionBttn(inputId = "selectall",label = "Select/Deselect all",style = "simple",
                         color = "primary",icon = icon("check-double"),size = "xs", block = TRUE),
              hr(),
              prettySwitch(inputId = "dygraph_sel",label = "Show stacked graphs (Not available yet)",
                           status = "success",fill = TRUE),
              circle = FALSE, status = "primary", size = "xs",
              icon = icon("gear"), width = "300px",
              tooltip = tooltipOptions(title = "Configure the TS appearance"),
              inputId = "ts_config"
            )
          ),
          fluidRow(
            column(12,
              #sliderInput(
                #"nrows", "Select initial data range:", 
                #min = 0, max = 10000, 
                #value = c(0,0),
                #step = 1000000
              #),
              dygraphOutput("ts_plot_dygraph") %>% withSpinner(),
              plotOutput("windows_plot"),
              uiOutput("windows_text")
            )
          )
          #verbatimTextOutput("projections_plot_interaction_info"),
          #verbatimTextOutput("point")
          
        )
}

embeddings_tab <- function(input, output, session) {
    
}


