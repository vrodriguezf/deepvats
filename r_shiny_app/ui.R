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
            numericInput("minPts_hdbscan", label = "Define value of minPts in HDBSCAN",value =100),
            checkboxInput("show_clusters", label = "Calculate and show clusters", value = FALSE),
            actionButton("update_clust", label = "Update clusters"),
            hr(),
            dropdownButton(
                tags$b("Set new coordinates to zoom"),
                splitLayout(cellWidths ="25%",
                    knobInput(inputId = "x_min",label = "x_min",value = NA,min = -100,max = 100,
                            width = "50",height = "50",displayPrevious = TRUE,lineCap = "round",
                            fgColor = "#1d89ff",inputColor = "#428BCA"),
                    knobInput(inputId = "x_max",label = "x_max",value = NA,min = -100,max = 100,
                              width = "50",height = "50",displayPrevious = TRUE,lineCap = "round",
                              fgColor = "#1d89ff",inputColor = "#428BCA"),
                    knobInput(inputId = "y_min",label = "y_min",value = NA,min = -100,max = 100,
                              width = "50",height = "50",displayPrevious = TRUE,lineCap = "round",
                              fgColor = "#1d89ff",inputColor = "#428BCA"),
                    knobInput(inputId = "y_max",label = "y_max",value = NA,min = -100,max = 100,
                              width = "50",height = "50",displayPrevious = TRUE,lineCap = "round",
                              fgColor = "#1d89ff",inputColor = "#428BCA")
                    ),
                actionBttn(inputId = "update_coord_graph",label = "Update coords.",style = "simple",
                           color = "primary",icon = icon("binoculars"),size = "xs", block = TRUE),
                hr(),
                tags$b("Configure aestethics"),
                sliderInput("path_line_size", label = "path_line_size", value = 0.08, min=0, max=5, step = 0.01),
                sliderInput("path_alpha", label = "path_alpha", value = 5/10, min=0, max=1, step = 0.01),
                sliderInput("point_alpha", label = "point_alpha", value = 1/10, min=0, max=1, step = 0.01),
                sliderInput("point_size", label = "point_size", value = 1, min=0, max=10, step = 0.5),
                actionBttn(inputId = "update_emb_graph",label = "Update aestethics",style = "simple",
                           color = "primary",icon = icon("bar-chart"),size = "xs", block = TRUE),
                circle = TRUE, status = "primary",
                icon = icon("gear"), width = "300px",
                tooltip = tooltipOptions(title = "Click to configure the appearance !")
            )
        ),
        # Show a plot of the generated distribution
        mainPanel(
            tabsetPanel(
                tabPanel(
                    "information_tab",
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
                    "embeddings_tab",
                    h2("Embeddings"),
                    plotOutput("embeddings_plot", 
                               click = "embeddings_click",
                               brush = "embeddings_brush") %>% withSpinner(),
                    dygraphOutput("ts_plot_dygraph") %>% withSpinner(),
                    #plotOutput("ts_plot") %>% withSpinner(),
                    verbatimTextOutput("embeddings_plot_interaction_info"),
                    verbatimTextOutput("point")
                    
                )
            )
        )
    )
))
