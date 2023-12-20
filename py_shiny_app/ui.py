from shiny import ui
from shinywidgets import output_widget

def create_ui():
    return (
        ui.page_fluid(
            output_widget("time_series_plot"),
            output_widget("umap_plot")
        )
    )
