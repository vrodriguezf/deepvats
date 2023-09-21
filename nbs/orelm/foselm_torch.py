from tsai.all import *
import nbs.orelm.utils as ut
import nbs.orelm.elm_torch as elm

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
      RLS=False         #Recuirsive Least squares 
    ):

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
    self.RLS=RLS

  def layerNormalization(self, H, scaleFactor=1, biasFactor=0):
    print("Foselm - Layer normalizatison")
    H_normalized = (H - H.mean()) / (torch.sqrt(H.var() + 0.0001))
    H_normalized = scaleFactor * H_normalized + biasFactor

    return H_normalized

  def calculateHiddenLayerActivation(self, features):
    """
    Calculate activation level of the hidden layer
    :param features feature matrix with dimension (numSamples, numInputs)
    :return: activation level (numSamples, numHiddenNeurons)
    """
    print("Foselm - Calculate Hidden layer activation")
    if self.activationFunction == "sig":
      V = ut.linear(features, self.inputWeights,self.bias)
      if self.LN:
        V = self.layerNormalization(V)
      H = ut.sigmoidActFunc(V)
    else:
      print ("FOS-ELM l-95 Unknown activation function type: " + self.activationFunction)
      raise NotImplementedError

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

  def train(self):
    features = self.features
    targets = self.targets
    print("Foselm -> Train")
    """
    Step 2: Sequential learning phase
    :param features feature matrix with dimension (numSamples, numInputs)
    :param targets target matrix with dimension (numSamples, numOutputs)
    """
    (numSamples, numOutputs) = targets.shape
    assert features.shape[0] == targets.shape[0], \
      "FOS_ELM:train: differs features "+str(features.shape[0])+" targets "+str(targets.shape[0])

    H = self.calculateHiddenLayerActivation(features)
    Ht = H.t()

    if self.RLS:

      self.RLS_k = torch.mm(torch.mm(self.M, Ht), torch.inverse(self.forgettingFactor * torch.eye(numSamples) + torch.mm(H, torch.mm(self.M, Ht))))
      self.RLS_e = targets - torch.mm(H,self.beta)
      self.beta = self.beta + torch.mm(self.RLS_k,self.RLS_e)
      self.M = 1/(self.forgettingFactor)*(self.M - torch.mm(self.RLS_k,torch.mm(H,self.M)))

    else:
      self.M = (1/self.forgettingFactor) * self.M - torch.mm((1/self.forgettingFactor) * self.M,
                                       torch.mm(Ht, torch.mm(
                                         torch.pinverse(torch.eye(numSamples) + torch.mm(H, torch.mm((1/self.forgettingFactor) * self.M, Ht))),
                                         torch.mm(H, (1/self.forgettingFactor) * self.M))))
      self.beta = self.beta + torch.mm(self.M, torch.mm(Ht, targets - torch.mm(H, self.beta)))
      # self.beta = (self.forgettingFactor)*self.beta + torch.mm(self.M, torch.mm(Ht, targets - torch.mm(H, (self.forgettingFactor)*self.beta)))
      # self.beta = (self.forgettingFactor)*self.beta + (self.forgettingFactor)*torch.mm(self.M, torch.mm(Ht, targets - torch.mm(H, self.beta)))
  
  

  def predict(self, features):
    """
    Make prediction with feature matrix
    :param features: feature matrix with dimension (numSamples, numInputs)
    :return: predictions with dimension (numSamples, numOutputs)
    """
    H = self.calculateHiddenLayerActivation(features)
    prediction = torch.mm(H, self.beta)
    return prediction

