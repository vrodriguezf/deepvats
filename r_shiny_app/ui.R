#
# This is the user-interface definition of a Shiny web application. You can
# run the application by clicking 'Run App' above.
#
# Find out more about building applications with Shiny here:
#
#    http://shiny.rstudio.com/
#

# Define UI for application that draws a histogram
shinyUI(fluidPage(

    # Application title
    titlePanel("Timecluster extension visualizer"),

    # Sidebar with a slider input for number of bins
    sidebarLayout(
        sidebarPanel(
            selectInput("run_dr", label = "Select a run", choices = NULL),
            hr(),
            # sliderInput("points_emb", "Select range of points to plot in the embedding", min = 1, max = 1000,value = c(200,500)),
            uiOutput("points_emb_controls"),
            # numericInput("points_emb", label = "Select # of points to plot in the embedding",value =40000),
            hr(),
            numericInput("min_cluster_size_hdbscan", label = "min_cluster_size",value =100),
            numericInput("min_samples_hdbscan", label = "min_samples",value =15),
            sliderInput("cluster_selection_epsilon_hdbscan", label = "cluster_selection_epsilon", value = 0.08, min=0, max=5, step = 0.01),
            pickerInput("metric_hdbscan",label = "Metric", choices = hdbscan_metrics, selected = "euclidean",options = list(`live-search` = TRUE)),
            checkboxInput("show_clusters", label = "Calculate and show clusters", value = FALSE),
            actionButton("update_clust", label = "Update clusters"),
            hr(),
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
                        h3("Embeddings artifact"),
                        dataTableOutput("embs_ar_info"),
                        h3("Time series artifact"),
                        dataTableOutput("ts_ar_info"),
                        h3("Configuration of the associated DCAE run"),
                        dataTableOutput("run_dcae_info"),
                    )
                ),
                tabPanel(
                    "Embeddings",
                    fluidRow(
                        h3("Embeddings"),
                        dropdownButton(
                            tags$b("Set height of the embeddings plot (px):"),
                            numericInput("embedding_plot_height", label = "Height",value =400),
                            hr(),
                            tags$b("Configure aestethics"),
                            sliderInput("path_line_size", label = "path_line_size", value = 0.08, min=0, max=5, step = 0.01),
                            sliderInput("path_alpha", label = "path_alpha", value = 5/10, min=0, max=1, step = 0.01),
                            sliderInput("point_alpha", label = "point_alpha", value = 1/10, min=0, max=1, step = 0.01),
                            sliderInput("point_size", label = "point_size", value = 1, min=0, max=10, step = 0.5),
                            actionBttn(inputId = "update_emb_graph",label = "Update aestethics",style = "simple",
                                       color = "primary",icon = icon("bar-chart"),size = "xs", block = TRUE),
                            circle = FALSE, status = "primary",
                            icon = icon("gear"), width = "300px",size = "xs",
                            tooltip = tooltipOptions(title = "Configure the embedding appearance"),
                            inputId = "embeddings_config"
                        ),
                        column(2,""),
                        column(8,align="center",
                               uiOutput("embeddings_plot_ui"),
                        ),
                        column(2,"")
                    ),
                    fluidRow(
                        h3("Original data"),
                        dropdownButton(
                            tags$b("Select/deselect variables"),
                            uiOutput("select_variables"),
                            actionBttn(inputId = "selectall",label = "Select/Deselect all",style = "simple",
                                       color = "primary",icon = icon("check-double"),size = "xs", block = TRUE),
                            hr(),
                            prettySwitch(inputId = "dygraph_sel",label = "Click to show stacked graphs", status = "success",fill = TRUE),
                            circle = FALSE, status = "primary", size = "xs",
                            icon = icon("gear"), width = "300px",
                            tooltip = tooltipOptions(title = "Configure the TS appearance"),
                            inputId = "ts_config"
                            ),
                        column(10,dygraphOutput("ts_plot_dygraph") %>% withSpinner()),
                        # uiOutput("ts_plot_dygraph") %>% withSpinner()),
                        #plotOutput("ts_plot") %>% withSpinner(),
                    ),
                    
                    verbatimTextOutput("embeddings_plot_interaction_info"),
                    verbatimTextOutput("point")
                    
                )
            )
        )
    )
))
