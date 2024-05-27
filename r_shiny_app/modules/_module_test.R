#Shiny's example

#For testing, use it:
# in Server.R via myModuleServer("myModule1", prefix = "Converted to uppercase: "), and
# in UI.R via myModuleUI("myModule1")
# Module definition, new method
myModuleUI <- function(id, label = "Input text: ") {
  ns <- NS(id)
  tabPanel("
    Shiny's module Example",
    tagList(
        textInput(ns("txt"), label),
        textOutput(ns("result"))
        )
  )
}

myModuleServer <- function(id, prefix = "") {
  moduleServer(
    id,
    function(input, output, session) {
      output$result <- renderText({
        paste0(prefix, toupper(input$txt))
      })
    }
  )
}
