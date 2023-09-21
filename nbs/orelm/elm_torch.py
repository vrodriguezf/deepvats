from tsai.all import * 
from nbs.orelm.utils import *

class ELM_torch(Module): 
    def __init__(
        self,
        inputs,             #nDimInput
        outputs,            #nDimOutput
        numHiddenNeurons,
    ):
        assert isinstance(inputs, (int, float)) and inputs >= 1, \
          'inputs must be numeric and greater than or equal to 1'
        assert isinstance(outputs, (int, float)) and outputs >= 1, \
          'outputs must be numeric and greater than or equal to 1'
        assert isinstance(numHiddenNeurons, (int, float)) and numHiddenNeurons >= 1, \
          'numHiddenNeurons must be numeric and greater than or equal to 1'
        self.inputs = inputs
        self.outputs = outputs 
        self.numHiddenNeurons = numHiddenNeurons
        
    def get_random_matrix(self, nrows, ncols):
        return torch.rand((nrows, ncols), dtype=torch.float32)   

    def get_random_InputWeights(self):
        self.inputWeights = self.get_random_matrix(self.numHiddenNeurons, self.inputs)
        return self.inputWeights
    def get_random_Bias(self):
        self.bias=self.get_random_matrix(1, self.numHiddenNeurons) * 2 - 1
        return self.bias
    def get_random_HiddenWeights(self):
        self.hiddenWeights = self.get_random_matrix(self.numHiddenNeurons, self.numHiddenNeurons)  
        return self.hiddenWeights