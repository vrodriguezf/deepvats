#
# This is the user-interface definition of a Shiny web application. You can
# run the application by clicking 'Run App' above.
#
# Find out more about building applications with Shiny here:
#
#    http://shiny.rstudio.com/
#

shinyUI(fluidPage(
  #theme = shinythemes::shinytheme("cerulean"),
  # Application title
  titlePanel("DeepVATS"),
  
  # Load Shinyjs
  shinyjs::useShinyjs(),
  
  # Sidebar with a slider input for number of bins
  sidebarLayout(
    sidebarPanel(
      fluidRow(
        shiny::actionButton("load_dataset", label = "Load dataset", icon = icon("database")),
        shiny::actionButton("load_embs", label = "Load embeddings", icon = icon("project-diagram"))
      ),
      hr(),
      selectizeInput("dataset", label = "Dataset", choices = NULL),
      selectizeInput("encoder", label = "Encoder", choices = NULL),
      #selectizeInput("embs_ar", label = "Select embeddings", choices = names(embs_l)),
      br(),
      sliderInput("wlen", "Select window size", min = 0, max = 0, value =0 , step = 1),
      sliderInput("stride", "Select stride", min = 0, max = 0, value = 0, step = 1),
      # sliderInput("points_emb", "Select range of points to plot in the projections", 
      #             min = 0, max = 0, value = 0, step = 1, ticks = FALSE),
      #uiOutput("points_prj_controls"),
      #### TODO: Check. Added for debugging solar 4_secs
      sliderInput("prj_n_neighbors", "Projections n_neighbors:", min = 1, max = 50, value = 15),
      sliderInput("prj_min_dist", "Projections min_dist:", min = 0.0001, max = 1, value = 0.1),
      #sliderInput("prj_random_state", "Projections random_state:", min = 0, max = 2^32-1, value = 1234),
      sliderInput("prj_random_state", "Projections random_state:", min = 0, max = 2000, value = 1234),
      ################
      radioButtons("cpu_flag", "Use: ", c("GPU", "CPU"), selected = "GPU", inline = T),
      radioButtons("dr_method", "Projection method:", c("UMAP", "TSNE", "PCA"), selected="UMAP", inline=T),
      br(),
      radioButtons("clustering_options", label = "Select a clustering option", selected = "no_clusters",
                   choices = c("No clusters" = "no_clusters",
                               #"Show precomputed clusters" = "precomputed_clusters",
                               "Calculate and show clusters" = "calculate_clusters")),
      # conditionalPanel(
      #     condition = "input.clustering_options == 'precomputed_clusters'",
      #     selectInput("clusters_labels_name", label = "Select a clusters_labels artifact", choices = NULL),
      #     tags$b("Selected 'clusters_labels' artifact description:"),
      #     textOutput("clusters_labels_ar_desc")
      # ),
      conditionalPanel(
          condition = "input.clustering_options == 'calculate_clusters'",
        selectInput("metric_hdbscan", label = "Metric", choices = DEFAULT_VALUES$metric_hdbscan),
        sliderInput("min_cluster_size_hdbscan", label = "min_cluster_size_hdbscan", 
                    value = DEFAULT_VALUES$min_cluster_size_hdbscan, min=0, max=200, step = 1),
        sliderInput("min_samples_hdbscan", label = "min_samples_hdbscan", 
                    value = DEFAULT_VALUES$min_samples_hdbscan, min=0, max=50, step = 1),
        sliderInput("cluster_selection_epsilon_hdbscan", label = "cluster_selection_epsilon", 
                    value = DEFAULT_VALUES$cluster_selection_epsilon_hdbscan, min=0, max=5, step = 0.01),
        actionBttn(inputId = "calculate_clusters", label = "Calculate and show clusters", style = "bordered",
                   color = "primary", size = "sm", block = TRUE)
      ),
    ),
    # Show a plot of the generated distribution
    mainPanel(
      tabsetPanel(
        id = "tabs",
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
          
        ),
        tabPanel(
          "Information",
          fluidRow(
            h3("Time series"),
            dataTableOutput("ts_ar_info"),
            h3("Configuration of the associated encoder"),
            dataTableOutput("enc_info")
          )
        ),
      )
    )
  )

  
))
