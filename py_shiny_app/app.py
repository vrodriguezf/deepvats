import global_ as g
import ui
import server 


app_ui = ui.create_ui()


app = g.App(app_ui, server.server) # create and run demo