import global_ as g
from shiny import render
from shinywidgets import output_widget, render_widget

def server(input, output, session):
    
    # Create some random data
    g.np.random.seed(0)
    dates = g.pd.date_range('20230101', periods=100)
    values = g.np.random.randn(100)
    df = g.pd.DataFrame({'Date': dates, 'Value': values})

    @output
    @render_widget
    def time_series_plot():
        fig = g.px.line(df, x='Date', y='Value', title='Time Series')
        # Aquí puedes añadir funcionalidades interactivas
        return fig


    # Calcular embeddings UMAP
    embeddings = g.compute_umap_embeddings(df)
    @output
    @render_widget
    def umap_plot():
        fig = g.px.scatter(
            x=embeddings[:, 0], 
            y=embeddings[:, 1], 
            title='UMAP Embeddings')
        # Aquí puedes añadir funcionalidades interactivas
        return fig
