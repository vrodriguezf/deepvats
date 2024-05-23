#############################################################
# Auxiliar function and variables for saving plots in local #
#############################################################

###############
# ReactiveVal #
###############
prj_plot_id <- reactiveVal(0)

#######
# GET #
#######
get_prjs_plot_name <- function(dataset_name, encoder_name, selected, cluster, input){
    set_plot_id()
    plt_name <- paste0(
        execution_id, "_",
        prj_plot_id(), "_",
        dataset_name, "_", 
        encoder_name, "_", 
        input$cpu_flag, "_", 
        input$dr_method, "_",  
        input$clustering_options, "_", 
        "zoom", "_", 
        input$zoom_btn, "_", 
        "point_alpha_",
        input$point_alpha, "_",
        "show_lines_",
        input$show_lines, "_",
        "prjs.png"
    )
    log_print(paste0("embeddings plot name", plt_name))
    plt_name
}

get_ts_plot_name <- function(dataset_name, encoder_name, input){
    log_print("Getting timeserie plot name")
    plt_name <- paste0(dataset_name,  "_", encoder_name, input$dr_method, "_ts.html")
    log_print(paste0("ts plot name: ", plt_name))
    plt_name
}

#######
# SET #
#######
set_plot_id <- function()({
    prj_plot_id(prj_plot_id()+1)
})

set_prjs_plot_name <- function(input, clustering_options, prjs_cluster) {
  reactive({
    dataset_name <- basename(input$dataset)
    encoder_name <- basename(input$encoder)
    get_prjs_plot_name(dataset_name, encoder_name, clustering_options$selected, prjs_cluster)
  })
}

set_ts_plot_name <- function(input, clustering_options, prjs_cluster) ({
    dataset_name <- basename(input$dataset)
    encoder_name <- basename(input$encoder)
    get_ts_plot_name(dataset_name, encoder_name)
})
