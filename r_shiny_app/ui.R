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
            selectInput("run_dr", label = "Select a run", choices = NULL)
        ),
        # Show a plot of the generated distribution
        mainPanel(
            tabsetPanel(
                tabPanel(
                    "information_tab",
                    fluidRow(
                        textOutput("run_dr_info_title"),
                        dataTableOutput("run_dr_info")
                    )
                ),
                tabPanel(
                    "embeddings_tab",
                    h2("Embeddings"),
                    plotOutput("embeddings_plot", 
                               click = "embeddings_click",
                               brush = "embeddings_brush") %>% withSpinner(),
                    dygraphOutput("ts_plot") %>% withSpinner(),
                    #plotOutput("ts_plot") %>% withSpinner(),
                    verbatimTextOutput("embeddings_plot_interaction_info"),
                    verbatimTextOutput("point")
                    
                )
            )
        )
    )
))
