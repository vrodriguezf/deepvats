info_tabUI <- function(id) {
    ns <- NS(id)
    tabPanel(
        "Information",
        fluidRow(
            h3("Time series"),
            dataTableOutput("ts_ar_info"),
            h3("Configuration of the associated encoder"),
            dataTableOutput("enc_info")
        )
    )
}

# Revisar si es necesario annadir codigo o se puede traer poco a poco de server
info_tab <- function(input, output, session) {
}