import global_ as g
from shiny import render


def server(input, output, session):
    @output
    @render.plot
    def plot():
        fig, ax = g.plt.subplots()
        im = ax.imshow(
            g.data2d, 
            cmap=input.cmap(), 
            vmin=input.range()[0], 
            vmax=input.range()[1]
        )
        fig.colorbar(im, ax=ax)
        return fig