#Function for making notebooks clearer
from IPython.display import clear_output, DisplayHandle
def update_patch(self, obj):
    clear_output(wait=True)
    self.display(obj)
    print("... Enabling Vs Code execution ...")
