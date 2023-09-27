"""
from tsai.all import * 
from nbs.orelm.utils import * 

class LinearRecurrent(Module):
    def __init__(
        self, 
        numSamples, 
        numInputs,
        numHiddenNeuron, 
        bias,
        print_flag = True
    ):
        self.numSamples         = numSamples
        self.numInputs          = numInputs
        self.numHiddenNeuron    = numHiddenNeuron
        self.bias               = bias
        self.print_flag         = print_flag
        self.input_linear = nn.Linear(input_size, hidden_size, bias=False)
        self.hidden_linear = nn.Linear(hidden_size, hidden_size, bias=False)
        self.bias = nn.Parameter(torch.zeros(1, hidden_size)) if bias else None
"""

import torch.nn as nn

class MyRNN(nn.RNN):
    def __init__(self, input_size, hidden_size, num_layers, bias=True, batch_first=False):
        super(MyRNN, self).__init__(input_size, hidden_size, num_layers, bias=bias, batch_first=batch_first)

"""
# Ejemplo de uso
input_size = 10  # Tamaño de entrada
hidden_size = 20  # Tamaño oculto
num_layers = 1  # Número de capas recurrentes
batch_size = 32  # Tamaño del lote
sequence_length = 10  # Longitud de la secuencia

# Crear una instancia de la capa MyRNN
my_rnn_layer = MyRNN(input_size, hidden_size, num_layers, bias=True, batch_first=True)

# Datos de entrada ficticios
input_data = torch.randn(batch_size, sequence_length, input_size)
initial_hidden_state = torch.zeros(num_layers, batch_size, hidden_size)  # Estado oculto inicial

# Propagar los datos a través de la capa
output, new_hidden_state = my_rnn_layer(input_data, initial_hidden_state)
"""