from tsai.all import *
import nbs.orelm.utils as ut
import nbs.orelm.elm_torch as elm
import nbs.orelm.rls_torch as rls
"""
Implementation of the fully online-sequential extreme learning machine (FOS-ELM)
Reference:
Wong, Pak Kin, et al. "Adaptive control using fully online sequential-extreme learning machine
and a case study on engine air-fuel ratio regulation." Mathematical Problems in Engineering 2014 (2014).
Note that the only difference between FOS-ELM and OS-ELM is in the initialize phase.
"""

class FOSELM_torch(elm.ELM_torch):
  
  def __init__(
      self, 
      inputs,           #nDimInput
      outputs,          #nDimOutput
      numHiddenNeurons, 
      activationFunction, 
      LN=False,         #Layer normalization flag
      forgettingFactor=0.999, 
      ORTH = False,     #Orthogonalization flag
      RLS_flag =False         #Recuirsive Least squares 
    ):
    super().__init__(inputs, outputs, numHiddenNeurons)

    self.activationFunction = activationFunction
    self.inputs = inputs
    self.outputs = outputs
    self.numHiddenNeurons = numHiddenNeurons

    # input to hidden weights
    self.get_random_InputWeights()
    self.ORTH = ORTH
    print("Foselm -- before bias")
    # bias of hidden units
    self.get_random_Bias()
    # hidden to output layer connection
    print("Foselm -- before beta")
    self.beta = self.get_random_matrix(self.numHiddenNeurons, self.outputs)
    
    self.LN = LN
    # auxiliary matrix used for sequential learning
    self.M = None
    self.forgettingFactor = forgettingFactor
    self.RLS = RLS_flag
    if (RLS_flag):
      self.rls_torch = rls.RLS_torch(self.M, self.beta, self.forgettingFactor)

  

  def calculateHiddenLayerActivation(self, features):
    """
    Calculate activation level of the hidden layer
    :param features feature matrix with dimension (numSamples, numInputs)
    :return: activation level (numSamples, numHiddenNeurons)
    """
    self.fprint("Foselm - Calculate Hidden layer activation", self.print_flag)
    if self.activationFunction == "sig":
      input_size  = self.inputs
      output_size = self.numHiddenNeurons
      l_layer = nn.Linear(input_size, output_size)
      l_layer.bias = nn.Parameter(self.bias)
      if self.LN:
        self.fprint("FOSELM: Create normalization layer", self.print_flag)
        ln_layer = self.get_ln_layer(V)
        self.fprint("FOSELM: Normalize lr output", self.print_flag)
        V = ln_layer(V)
      H = ut.sigmoidActFunc(V)
    else:
      self.fprint("FOS-ELM l-95 Unknown activation function type: " + self.activationFunction, self.print_flag)
      raise NotImplementedError
    print("FOSELM: Calculate hidden layer activation -->")
    return H
  #Añadiendo para pasar a torch
  def forward(self, features):
    print("Foselm - forward")
    return self.calculateHiddenLayerActivation(features)



  def initializePhase(self, lamb=0.0001):
    """
    Step 1: Initialization phase
    """
    print("Foselm - initialize phase")
    # randomly initialize the input->hidden connections
    self.get_random_InputWeights()
    self.inputWeights = self.inputWeights * 2 - 1

    if self.ORTH:
      if self.numHiddenNeurons > self.inputs:
        self.inputWeights = ut.orthogonalization(self.inputWeights)
      else:
        self.inputWeights = ut.orthogonalization(self.inputWeights.t())
        self.inputWeights = self.inputWeights.t()

    if self.activationFunction == "sig":
      self.get_random_Bias()
    else:
      print ("119: Unknown activation function type: " + self.activationFunction)
      raise "Not implemented"

    self.M = torch.inverse(lamb*torch.eye(self.numHiddenNeurons))
    self.beta = torch.zeros(self.numHiddenNeurons,self.outputs)    
    
  def compute_coefficients(self, targets, H, Ht):
    self.beta + torch.mm(self.M, torch.mm(Ht, targets - torch.mm(H, self.beta)))
    return self.beta
  def compute_inverse_covariance_matrix(self, targets, H, Ht):
    (numSamples, _) = targets.shape
    self.M = (1/self.forgettingFactor) * self.M - torch.mm(
      (1/self.forgettingFactor) * self.M,
      torch.mm(
        Ht, 
        torch.mm(
          torch.pinverse(
            torch.eye(numSamples) + torch.mm(
              H, 
              torch.mm((
                1/self.forgettingFactor) * self.M, 
                Ht
              )
            )
          ),
          torch.mm(H, (1/self.forgettingFactor) * self.M)
        )
      )
    )
    return self.M 


  
  def train_func(self, features, targets):
    self.fprint("--> Foselm: Train", self.print_flag)
    """
    Step 2: Sequential learning phase
    :param features feature matrix with dimension (numSamples, numInputs) #, numSteps
    :param targets target matrix with dimension (numSamples, numOutputs) 
    """
        #if len(targets.shape) == 3:
     # print("FOSELM:TRAIN:3SHAPED")
     
    (num_windows, num_samples, num_outputs) = targets.shape
    (num_samples, num_vars, num_steps) = features.shape
    
    print("FOSELM Features & targets shape")
    print("Features ~" +str(features.shape))
    print("Targets ~" +str(targets.shape))
    print(num_samples, num_vars)
    assert num_samples == num_vars, \
      "FOS_ELM:train: differs features "+ str(num_vars) + " targets "+str(num_samples)
    
    #Train
    H = self.calculateHiddenLayerActivation(features)
    Ht = H.t() #Traspose
    if self.RLS:
      self.beta, self.M = self.rls_torch.compute_recursive_least_squares(targets, H, Ht)
    else:
      print("non RLS")
      self.M    = self.compute_inverse_covariance_matrix(targets, H, Ht)
      self.beta = self.compute_coefficients(targets, H, Ht)
    
    self.fprint("FOSELM:Train:END -->", self.print_flag)

  
  

  def predict(self, features, print_flag = True):
    """
    Make prediction with feature matrix
    :param features: feature matrix with dimension (numSamples, numInputs)
    :return: predictions with dimension (numSamples, numOutputs)
    """
    self.fprint("--> ORELM: Prediction", self.print_flag)
    H = self.calculateHiddenLayerActivation(features)
    self.fprint("Just before prediction", self.print_flag)
    prediction = torch.mm(H, self.beta)
    self.fprint("ORELM: Prediction -->", self.print_flag)
    return prediction

