##########################################
## This is an auxiliar .py for cropping ##
## Used for cropping PP and TS          ##
## It's meant to use in your computer   ##
## for screenshots. Do not use in docker##
##########################################
#### INSTRUCTIONS ####
# Open shiny-server
# Open development tools ctrl+shift+I
# Open the multi-resolution path (botton with a computer-smartphone image)
# Fix resolutiobn 1920x1080
# For each case you may analyze:
# -- Exec the case here or switching with the multi-resolution button
# -- Come back to the multi-resolution windows
# -- In the three dots button, click "Capture full size screenshot"
# -- Make sure your screenshots have a descriptive name for your case
# -- Move all the screenshots to the "input_folder" path and exec this python (you will need python & pillow in local)
#### ------------ ####

# --- Libraries
from PIL import Image
import os

# --- Global variates
input_folder = "capturas"
output_folder = "capturas_cortadas"
left_margin_ratio = 0.33333
# Projections plot
projections_crop_height = 860
projections_top_padding = 420
# Original data plot
time_series_y_0 = projections_crop_height+projections_top_padding+100

# --- Utils
def crop_box(tabs_height = 0, crop_height = 500, im = None, top_padding = 420, left_padding= 0):
    img_width, _ = im.size
    # Calcular el margen superior a omitir
    crop_x = (int(img_width * left_margin_ratio))+left_padding
    # Definir el área de recorte
    box = (crop_x, tabs_height+ top_padding, img_width, top_padding + crop_height + tabs_height)
    cropped_im = im.crop(box)
    return cropped_im

def crop_projections_plot(im):
    return crop_box(tabs_height=0, crop_height= projections_crop_height, im = im, top_padding = projections_top_padding)

def crop_timeseries_plot(im):
    return crop_box(tabs_height=0, crop_height=projections_crop_height, im = im, top_padding=time_series_y_0, left_padding=100)

# --- Ensure that the output_folder exists
if not os.path.exists(output_folder):
    os.makedirs(output_folder)

# --- For each image in the input folder, crop PP & TS plot
for file_name in os.listdir(input_folder):
    if file_name.lower().endswith((".png", ".jpg", ".jpeg", ".bmp", ".gif")):
        img_path = os.path.join(input_folder, file_name)
        with Image.open(img_path) as im:
            projections = crop_projections_plot(im)
            projections.save(os.path.join(output_folder, f"projections_plot_{file_name}"))
            ts = crop_timeseries_plot(im)
            ts.save(os.path.join(output_folder, f"timeseries_plot_{file_name}"))