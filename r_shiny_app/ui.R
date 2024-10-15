source("./lib/ui/ui.R")
source("./modules/information.R")
source("./modules/mplots.R")
source("./modules/embeddings.R")
source("./modules/parameters.R")
#
# This is the user-interface definition of a Shiny web application. You can
# run the application by clicking 'Run App' above.
#
# Find out more about building applications with Shiny here:
#
#    http://shiny.rstudio.com/
#

shinyUI(fluidPage(
  ################################################
  ################## JScript Logs ################
  ################################################
  tags$head(
    tags$script(log_script), 
    tags$style(HTML(rotate_plot_style)),
    tags$link(rel="stylesheet", href="https://use.fontawesome.com/releases/v5.8.2/css/all.css") #--#
  ),
  
  #theme = shinythemes::shinytheme("cerulean"),
  # Application title
  titlePanel("DeepVATS"),
  
  # Load Shinyjs
  shinyjs::useShinyjs(),
  
  # Sidebar with a slider input for number of bins
  sidebarLayout(
    sidebarPanel(
      load_datasetUI("load_dataset1"),
      hr(),
      select_datasetUI("datasetModule"),
      selectizeInput("encoder", label = "Encoder", choices = NULL),
      actionButton("play_pause", "Run!", icon = shiny::icon("play")),
      actionButton("cuda", "Remove CUDA objects", icon = shiny::icon("trash")),
      #selectizeInput("embs_ar", label = "Select embeddings", choices = names(embs_l)),
      br(),
      actionBttn(
        inputId = "get_tsdf", 
        label = "Activate/Deactivate DF loading", 
        style = "bordered", 
        color = "primary", 
        size = "sm", 
        block = TRUE  
      ),      
      br(),
      actionBttn(
        inputId = "restore_wlen_stride",
        label = "Restore window size and stride",
        style = "bordered",
        color = "primary",
        siz   = "sm",
        block = TRUE
      ),
      sliderInput("wlen", "Select window size", min = 0, max = 0, value =0 , step = 1),
      numericInput("wlen_text", "Enter window size", value = 0, min = 0, max = 1000000, step = 1),
      sliderInput("stride", "Select stride", min = 0, max = 0, value = 0, step = 1),
      conditionalPanel(
        condition = "input.encoder.indexOf('moirai') != -1",
        selectInput(
          "patch_size", 
          "Select patch size", 
          choices = c(8, 16, 32, 64, 128), 
          selected = 8
        )
      ),
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
      radioButtons("dr_method", "Projection method:", c("UMAP", "TSNE", "PCA", "PCA_UMAP"), selected="PCA_UMAP", inline=T),
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
      )
    ),
    # Show a plot of the generated distribution
    mainPanel(
      tabsetPanel(
        id = "tabs",
        embeddings_tabUI("embs_tab"),
        info_tabUI("inf_tab"),
        mplot_tabUI("mplot_tab1"),
        #myModuleUI("myModule1"),
      ######################## JSCript Logs button ###############################
        tabPanel(
          "Logs",
          fluidRow(
            h3("Logs"),
            verbatimTextOutput("logsOutput"),
            h3("Log dataframe"),
            shiny::actionButton("update_logs", label = "Update logs", icon = shiny::icon("refresh")),
            shiny::downloadButton("download_data", "Download logs as CSV"),
            #shinyWidgets::sliderTextInput(
            #  "timestamp_range", 
            #  "Select Time Range:",
            #  choices = c("Loading..."="Loading..."), #setNames(as.character(seq(0,10,1)), seq(0,10,1)),
            #  selected = c("Loading...", "Loading..."),
            #  animate = TRUE
            #),
            #verbatimTextOutput(outputId = "res"),
            dataTableOutput("log_output")
          )
        )
      )
    )
  )
))
