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
            actionButton("update_clust", label = "Update clusters")
            
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
