source("./lib/ui/ui.R", encoding = "utf-8")
source("./lib/global/global.R", encoding = "utf-8")
source("./modules/information.R", encoding = "utf-8")
source("./modules/mplots.R", encoding = "utf-8")
source("./modules/embeddings.R", encoding = "utf-8")
source("./modules/parameters.R", encoding = "utf-8")
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
    tags$link(rel="stylesheet", href="https://use.fontawesome.com/releases/v5.8.2/css/all.css")
  ),
  #theme = shinythemes::shinytheme("cerulean"),
  # Application title
  titlePanel("DeepVATS"),
  
  # Load Shinyjs
  shinyjs::useShinyjs(),
  extendShinyjs( 
    text = jsCode,  
    functions = c("checkEnabled") 
  ),
  # Sidebar with a slider input for number of bins
  sidebarLayout(
    sidebarPanel(
      textOutput("log_path"),
      load_datasetUI("load_dataset1"),
      checkboxInput("preprocess_dataset", "Preprocess Dataset", value = FALSE),
      conditionalPanel(
        condition = "input.preprocess_dataset == true",
        actionButton("preprocess_play", "Preprocess", icon = shiny::icon("play")),
        selectInput("task_type", "Select Task Type", choices = list (
          "Detect outlier points" = "point_outlier",
          "Detect outlier sequences" = "sequence_outlier",
          "Segmentate" = "segments",
          "Detect trends" = "trends"
          ), 
          selected = NULL
        ),
        conditionalPanel(
          condition = "input.task_type == 'point_outlier'",
          checkboxGroupInput("methods_point", "Smoothing Options for Point Outliers",
          choices = list(
            "StandardScaler" = "standard_scaler",
            "EllipticEnvelope" = "elliptic_envelope",
            "Median Filter" = "median_filter"
            ),
            selected = NULL
          )
        ),  
        conditionalPanel(
          condition = "input.task_type == 'sequence_outlier'",
          checkboxGroupInput(
            "methods_sequence", 
            "Smoothing Options for Sequence Outliers",
            choices = list(
              "DBSCAN"                = "dbscan",
              "IsolationForest"       = "isolation_forest",
              "Moving Average Filter" = "moving_average",
              "Range Normalization"   = "range_normalization"
            ),
            selected                = NULL
          ),
          conditionalPanel(
            condition = "input.methods_sequence.includes('range_normalization')",
            sliderInput("so_range_normalization_sections", "Select number of sections - 0 for using size", min = 0, max = 1, value =0 , step = 1),
            sliderInput("so_range_normalization_sections_size", "Select sections size (range)- 0 for using n. sections", min = 0, max = 1, value =0 , step = 1),
            textInput("so_text_rns", "Set number of sections:", value = 0),
            textInput("so_text_rnsz", "Set section size:", value = 0)
          )
        ),
        conditionalPanel(
          condition = "input.task_type == 'segments'",
          checkboxGroupInput(
            "methods_segments", "Smoothing Options for Segments",
            choices = list(
              "KMeans"                            = "kmeans",
              "Moving Average Filter"             = "moving_average",
              "Wavelet Transform (Not Available)" = "wavelet_transform",
              "Range Normalization"               = "range_normalization"
            ),
            selected = NULL
          ),
          conditionalPanel(
            condition = "input.methods_segments.includes('range_normalization')",
            sliderInput("ss_range_normalization_sections", "Select number of sections - 0 for using size", min = 0, max = 1, value =0 , step = 1),
            sliderInput("ss_range_normalization_sections_size", "Select sections size (range) - 0 for using n. sections", min = 0, max = 1, value =0 , step = 1),
            textInput("ss_text_rns", "Set number of section:", value = 0),
            textInput("ss_text_rnsz", "Set section size:", value = 0)
          )
        ),
        conditionalPanel(
          condition = "input.methods_sequence.includes('range_normalization') || input.methods_segments.includes('range_normalization')",
          textOutput("proposed_section_sizes")
        ),

        conditionalPanel(
          condition = "input.task_type == 'trends'",
          checkboxGroupInput(
            "methods_trends", "Smoothing Options for Trends",
            choices = list(
              "PCA"                         = "pca",
              "Exponential Smoothing"       = "exp_smoothing",
              "Linear Regression on Window" = "linear_regression"
              ),
              selected = NULL
            )
          )
      ),

      hr(),
      select_datasetUI("datasetModule"),
      fluidRow(
        column(4, selectizeInput("encoder", label = "Encoder", choices = NULL)),
        column(2,checkboxInput("fine_tune", "Fine-tune", value = FALSE)),
        column(4,
          conditionalPanel(
            condition = "input.fine_tune == true",
              selectInput(
                "ft_df", "Choose a dataset",
                choices = list(
                  "ft_df_ts" = "Use the original dataset",
                  "ft_df_ts_preprocess" = "Use the preprocessed dataset"
                )
              ),
            textInput("ft_batch_size", "Batch Size", value = 32),
            textOutput("ft_batch_size_value"),
            textInput("ft_mask_window_percent", "Percentage of windows/dataset to use for the training", value = 0.15), # mask
            textInput("ft_window_percent", "masked windows percent", value = 0.25), # mask
            textOutput("ft_window_percent_value"),
            textInput("ft_training_percent", "Training windows percent", value = 0.1),
            textInput("ft_validation_percent", "Validation windows percent", value = 0.3),
            textInput("ft_num_epochs", "Number of epochs", value = 17),
            textInput("ft_min_windows_distance", "Minimum distance between windows sizes", value = 5),
            textInput("ft_num_windows", "Number of windows", value = 1),
            verbatimTextOutput("ft_output"),
            selectInput("ft_dataset_option", "Choose how to use the dataset in fine-tuning", 
            choices = list(
              "use_ft_window_percent" = "Fine-tune using the window percent.",
              "use_ft_num_windows" = "Fine-tune fixing the number of windows",
              "use_full_dataset" = "Fine-tune using the full dataset"
            )),
            checkboxGroupInput(
              inputId = "masking_options",
              label = "Select tsai masking options:",
              choices = list(
                "ft_mask_future"   = "Choose if you want to mask future timestamps.",
                "ft_mask_stateful" = "Choose if you want to mask past timestamps",
                "ft_sync"          = "*Todo* Choose if you want to sync masking in all time series variables"
              )
            ),
            actionButton("fine_tune_play", "Shot!", icon = shiny::icon("play"))
          )
        )
      ),
      
      actionButton("play_pause", "Start with the dataset!", icon = shiny::icon("play")),
      actionButton("play_embs", "Get Embeddings!", icon = shiny::icon("play")),
      conditionalPanel(
        condition = "input.preprocess_dataset == true",
        checkboxInput("embs_preprocess", "Use preprocessed dataset for getting embeddings", value = FALSE)
      ),
      actionButton("cuda", "Remove CUDA cache", icon = shiny::icon("trash")),
      #selectizeInput("embs_ar", label = "Select embeddings", choices = names(embs_l)),
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
      textOutput("proposed_wlen"),
      numericInput("wlen_text", "Enter window size", value = 0, min = 0, max = 1000000, step = 1),
      sliderInput("stride", "Select stride", min = 0, max = 0, value = 1, step = 1),
      conditionalPanel(
        condition = "input.encoder.indexOf('moirai') != -1",
        selectInput(
          "patch_size", 
          "Select patch size", 
          choices = c(8, 16, 32, 64, 128), 
          selected = 8
        )
      ),
      conditionalPanel(
        condition = "input.encoder.indexOf('moment') != -1",
        numericInput(
          "padd_step", "Enter padding step size in case of error", 
          value = 10, 
          min = 2, 
          max = 1000000, 
          step = 1
        )
      ),
      # sliderInput("points_emb", "Select range of points to plot in the projections", 
      #             min = 0, max = 0, value = 0, step = 1, ticks = FALSE),
      #uiOutput("points_prj_controls"),
      ################
      radioButtons("cpu_flag", "Use: ", c("GPU", "CPU"), selected = "GPU", inline = T),
      radioButtons("dr_method", "Projection method:", c("UMAP", "TSNE", "PCA", "PCA_UMAP"), selected="PCA_UMAP", inline=T),
      conditionalPanel(
        condition = "input.dr_method == 'UMAP' || input.dr_method == 'PCA_UMAP'",
        div(
          class = "panel panel-default",
          div(
            class = "panel-heading",
            style = "cursor: pointer;",
            `data-toggle` = "collapse",
            `data-target` = "#umapOptionsPanel",
            div("UMAP projection options", 
               span(class = "caret") # Arrow
            ) 
          ),
          div(
            id = "umapOptionsPanel",
            class = "panel-collapse collapse",
            sliderInput("prj_n_neighbors", "Projection  s n_neighbors:", min = 1, max = 50, value = 15),
            sliderInput("prj_min_dist", "Projections min_dist:", min = 0.0001, max = 1, value = 0.1),
            sliderInput("prj_random_state", "Projections random_state:", min = 0, max = 2000, value = 1234),
            numericInput("prj_random_state_text", "Enter Projections random_state", value = 0, min = 0, max = 1000000, step = 1)
          )
        )
      ),
      conditionalPanel(
        condition = "input.dr_method == 'PCA' || input.dr_method == 'PCA_UMAP'",
        div(
          class = "panel panel-default",
          div(
            class = "panel-heading",
            style = "cursor: pointer;",
            `data-toggle` = "collapse",
            `data-target` = "#pcaOptionsPanel",
            div("PCA projection options", 
               span(class = "caret") # Arrow
            ) 
          ),
          div(
            id = "pcaOptionsPanel",
            class = "panel-collapse collapse",
            sliderInput("pca_n_components", "PCA n_components:", min = 1, max = 100, value = 3),
            sliderInput("pca_random_state", "PCA random_state:", min = 0, max = 2000, value = 1234),
            numericInput("pca_random_state_text", "Enter PCA random_state", value = 0, min = 0, max = 1000000, step = 1),
          )
        )
      ),
      conditionalPanel(
        condition = "input.dr_method == 'TSNE'",
        div(
          class = "panel panel-default",
          div(
            class = "panel-heading",
            style = "cursor: pointer;",
            `data-toggle` = "collapse",
            `data-target` = "#tsneOptionsPanel",
            div("TSNE projection options", 
               span(class = "caret") # Arrow
            ) 
          ),
          div(
            id = "tsneOptionsPanel",
            class = "panel-collapse collapse",
            sliderInput("tsne_random_state", "PCA random_state:", min = 0, max = 2000, value = 1234),
            numericInput("tsne_random_state_text", "Enter TSNE random_state", value = 0, min = 0, max = 1000000, step = 1),
          )
        )
      ),
      
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
        div(
          class = "panel panel-default",
          div(
            class = "panel-heading",
            style = "cursor: pointer;",
            `data-toggle` = "collapse",
            `data-target` = "#clusteringOptionsPanel",
            div("Clustering Options", 
               span(class = "caret") # Arrow
            ) 
          ),
          div(
            id = "clusteringOptionsPanel",
            class = "panel-collapse collapse",
          
              selectInput("metric_hdbscan", label = "Metric", choices = DEFAULT_VALUES$metric_hdbscan),
              sliderInput("min_cluster_size_hdbscan", label = "min_cluster_size_hdbscan", 
                        value = DEFAULT_VALUES$min_cluster_size_hdbscan, min=0, max=200, step = 1),
              sliderInput("min_samples_hdbscan", label = "min_samples_hdbscan", 
                        value = DEFAULT_VALUES$min_samples_hdbscan, min=0, max=50, step = 1),
              sliderInput("cluster_selection_epsilon_hdbscan", label = "cluster_selection_epsilon", 
                        value = DEFAULT_VALUES$cluster_selection_epsilon_hdbscan, min=0, max=5, step = 0.01)
          )
        ),
        actionBttn(
          inputId = "calculate_clusters", label = "Calculate and show clusters", 
          style = "bordered", color = "primary", size = "sm", block = TRUE)
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
