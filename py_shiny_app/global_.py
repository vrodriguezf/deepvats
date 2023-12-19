from shiny import App, ui, render
import matplotlib.pyplot as plt
import numpy as np

# Create some random data
t = np.linspace(0, 2 * np.pi, 1024)
data2d = np.sin(t)[:, np.newaxis] * np.cos(t)[np.newaxis, :]
