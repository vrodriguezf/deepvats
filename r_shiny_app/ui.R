#
# This is the user-interface definition of a Shiny web application. You can
# run the application by clicking 'Run App' above.
#
# Find out more about building applications with Shiny here:
#
#    http://shiny.rstudio.com/
#

shinyUI(fluidPage(

    # Application title
    titlePanel("Timecluster hub"),
    
    # Load Shinyjs
    shinyjs::useShinyjs(),

    # Sidebar with a slider input for number of bins
    sidebarLayout(
        sidebarPanel(
            selectInput("run_dr", label = "Select a run", choices = NULL),
            br(),
            sliderInput("points_emb", "Select range of points to plot in the projections", min = 1, max = 2, value = c(1,2), step = 1, ticks = FALSE),
            #uiOutput("points_emb_controls"),
            br(),
            radioButtons("clustering_options", label = "Select a clustering option", selected = "no_clusters",
                         choices = c("No clusters" = "no_clusters",
                                     "Show precomputed clusters" = "precomputed_clusters",
                                     "Calculate and show clusters" = "calculate_clusters")),
            conditionalPanel(
                condition = "input.clustering_options == 'precomputed_clusters'",
                selectInput("clusters_labels_name", label = "Select a clusters_labels artifact", choices = NULL),
                tags$b("Selected 'clusters_labels' artifact description:"),
                textOutput("clusters_labels_ar_desc")
            ),
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
                    "Information",
                    fluidRow(
                        uiOutput("run_dr_info_title"),
                        dataTableOutput("run_dr_info"),
                        h3("Projections"),
                        dataTableOutput("prjs_ar_info"),
                        h3("Time series"),
                        dataTableOutput("ts_ar_info"),
                        h3("Configuration of the associated encoder"),
                        dataTableOutput("run_enc_info"),
                    )
                ),
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
                                    actionBttn(inputId = "update_emb_graph",label = "Update aestethics",style = "simple",
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
                            column(7,
                                   
                            ),
                        ),
                        column(2,),
                        column(8,align="center",
                               uiOutput("projections_plot_ui"),
                        ),
                        column(2,"")
                    ),
                    fluidRow(
                        h3("Original data"),
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
                            ),
                        column(10,dygraphOutput("ts_plot_dygraph") %>% withSpinner()),
                    ),
                    
                    verbatimTextOutput("projections_plot_interaction_info"),
                    verbatimTextOutput("point")
                    
                )
            )
        )
    )
))
