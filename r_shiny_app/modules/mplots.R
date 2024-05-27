mplot_tabUI <- function(id) {
    ns <- NS(id)
    tabPanel(
        "MPlot | Similarity Matrix Plot",
        # --- Aquí hay que poner los controladores
        # --- Hay que tener cuidado con el alto y el ancho para pasárselo a python
        fluidRow(
            h3("MPlot | Similarity Matrix Plot"),
            #embeddings_aesthetics("embeddings_aesthetics"),
            column(
                8,
                #embeddings_zoom_button("embeddings_zoom_button"),
                #embeddings_plot_windows("embeddings_plot_windows"),
            ),
            column(3)
        ),
        #-- Aqui va la referencia al output
        fluidRow(
            # Matrix profile plot
            # uiOutput("matrix_profile_plot_ui")
            # Similarity matrix plot (MPlot)
            # uiOutput("mplot_ui")
        )
    )
    #-- Aqui hay que poner un plot para TA y otro para TB
    #original_data_plot1("original_data_plot2")
    #original_data_plot2("original_data_plot2")
    
}

mplot_tab <- function(input, output, session) {
    #-- Aqui habra que poner el plot del output
    
}