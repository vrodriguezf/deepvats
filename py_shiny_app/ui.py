import global_ as g

def create_ui():
    return g.ui.page_fixed(
        g.ui.h2("Playing with colormaps"),
        g.ui.markdown("""
            This app is based on a [Matplotlib example][0] that displays 2D data
            with a user-adjustable colormap. We use a range slider to set the data
            range that is covered by the colormap.

            [0]: https://matplotlib.org/3.5.3/gallery/userdemo/colormap_interactive_adjustment.html
        """),
        g.ui.layout_sidebar(
            g.ui.panel_sidebar(
                g.ui.input_radio_buttons("cmap", "Colormap type",
                    dict(
                        viridis="Perceptual", 
                        gist_heat="Sequential", 
                        RdYlBu="Diverging"
                        )
                ),
                g.ui.input_slider(
                    "range", 
                    "Color range", -1, 1, 
                    value=(-1, 1), step=0.05
                ),
            ),
            g.ui.panel_main(
                g.ui.output_plot("plot")
            )
        )

    )