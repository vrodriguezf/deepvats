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
      RLS_flag =False,         #Recuirsive Least squares 
      seq_len = 1
    ):
    super().__init__(inputs, outputs, numHiddenNeurons)

    self.activationFunction = activationFunction
    self.inputs = inputs
    self.outputs = outputs
    self.numHiddenNeurons = numHiddenNeurons
    self.window_size = seq_len
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
    :param features feature matrix with dimension (numSamples, numInputs, num_steps)
    :return: activation level (numSamples, numHiddenNeurons)
    """
    self.fprint("Foselm - Calculate Hidden layer activation", self.print_flag)
    if self.activationFunction == "sig":
      #input_size  = features.shape[0]
      #input_size  = features.shape[1]
      input_size  = features.shape[2]
      output_size = self.numHiddenNeurons
      
      print("FOSELM hidden - create l_layer")
      l_layer = nn.Linear(input_size, output_size)
      print("FOSELM hidden - set bias matrix")
      l_layer.bias = nn.Parameter(self.bias)
      V = l_layer(features)
      if self.LN:
        self.fprint("FOSELM: Create normalization layer", self.print_flag)
        ln_layer = self.get_ln_layer(V)
        self.fprint("FOSELM: Normalize lr output", self.print_flag)
        V = ln_layer(V)
      H = torch.sigmoid(V)
    else:
      self.fprint("FOS-ELM l-95 Unknown activation function type: " + self.activationFunction, self.print_flag)
      raise NotImplementedError
    print("FOSELM: Calculate hidden layer activation -->")
    return H
  

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
    diff      = targets - torch.matmul(H, self.beta)
    self.beta = self.beta + torch.matmul(self.M, torch.matmul(Ht, diff))
    return self.beta
  
  def compute_inverse_covariance_matrix(self, targets, H, Ht, num_steps):
    self.fprint("Foselm: --> Compute inverse covariance matrix", self.print_flag)
    num_samples, num_outputs, num_steps = targets.shape
    print("samples ", num_samples, " outputs ", num_outputs, " steps ", num_steps)
    
    for i in range (num_samples):
      I = torch.eye(num_outputs) #Create identity matrix
      factor = 1/self.forgettingFactor
      factor_M = factor*self.M
      self.fprint("Get temp1", self.print_flag)
      temp1 = torch.matmul(H[i], factor_M)
      self.fprint("Get temp2", self.print_flag)
      temp2 = torch.matmul(factor_M, Ht[i])
      self.fprint("Get covariance matrix", self.print_flag)
      self.fprint("I ~ " + str(I.shape) + "H ~ " + str(H[i].shape) + "temp2 ~ " + str(temp2.shape), self.print_flag)
      covariance_matrix = I + torch.matmul(H[i], temp2)
      self.fprint("Get inverse covariance matrix", self.print_flag)
      self.fprint("covariance matrix ~ " + str(covariance_matrix.shape), self.print_flag)
      inverse_covariance_matrix = torch.pinverse(covariance_matrix)
      self.fprint("self.M = ... ~ " + str(self.M.shape), self.print_flag)
      self.fprint("inverse" + str(inverse_covariance_matrix.shape)  + "temp1 ~ " + str(temp1.shape), self.print_flag)
      Mi = factor_M - torch.matmul( 
      factor_M, torch.matmul(Ht[i], torch.matmul(inverse_covariance_matrix,temp1)))
      print("Mi ~", Mi.shape)
      print("M ~", self.M.shape)
      self.M = Mi
    self.fprint("Foselm: Compute inverse covariance matrix -->", self.print_flag)
    """
    I = torch.eye(num_samples) #Create identity matrix
    factor = 1/self.forgettingFactor
    factor_M = factor*self.M
    self.fprint("Get temp1", self.print_flag)
    temp1 = torch.matmul(H, factor_M)
    self.fprint("Get temp2", self.print_flag)
    temp2 = torch.matmul(factor_M, Ht)
    self.fprint("Get covariance matrix", self.print_flag)
    self.fprint("I ~ " + str(I.shape) + "H ~ " + str(H.shape) + "temp2 ~ " + str(temp2.shape), self.print_flag)
    covariance_matrix = I + torch.matmul(H, temp2)
    self.fprint("Get inverse covariance matrix", self.print_flag)
    self.fprint("covariance matrix ~ " + str(covariance_matrix.shape), self.print_flag)
    inverse_covariance_matrix = torch.pinverse(covariance_matrix)
    self.fprint("self.M = ...", self.print_flag)
    self.fprint("inverse" + str(inverse_covariance_matrix.shape)  + "temp1 ~ " + str(temp1.shape), self.print_flag)
    self.M = factor_M - torch.matmul( 
      factor_M, torch.matmul(Ht, torch.matmul(inverse_covariance_matrix,temp1)))
    self.fprint("Foselm: Compute inverse covariance matrix -->", self.print_flag)
    """
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
    assert features.shape[0] == targets.shape[0], \
      "FOS_ELM:train: differs number of samples features "+ str(features.shape[0]) + " targets "+str(targets.shape[0])
    assert features.shape[2] == targets.shape[2], \
      "FOS_ELM:train: differs number of steps features "+ str(features.shape[0]) + " targets "+str(targets.shape[0])

    (num_samples, num_outputs, num_steps) = targets.shape
    (num_samples, num_inputs, num_steps) = features.shape
    
    print("FOSELM Features & targets shape")
    print("Features ~ (samples, outputs (vars), steps) = " +str(features.shape))
    print("Targets ~ (samples, inputs (vars), steps) = " +str(targets.shape))
    
    H = self.calculateHiddenLayerActivation(features)
    Ht = H.transpose(1,2)
    if self.RLS:
      #Flatten
      H = H.view(-1, num_inputs, num_samples)
      Ht = Ht.view(-1, num_samples, num_inputs)
      targets = targets.view(-1, num_outputs, num_samples)
      #Compute
      self.beta, self.M = self.rls_torch.compute_recursive_least_squares(targets, H, Ht)
    else:
      print("non RLS")
      print("targets ~ " + str(targets.shape))
      print("H ~ " + str(H.shape)) #(n_samples, 1, num_hidden_neurons)
      print("Ht ~ " + str(Ht.shape)) 
      self.M    = self.compute_inverse_covariance_matrix(targets, H, Ht, num_steps)
      self.beta = self.compute_coefficients(targets, H, Ht)
    self.fprint("FOSELM:Train:END -->", self.print_flag)
    

    """
    #Latten & splite into windows
    num_samples, num_inputs, num_steps = targets.shape
    _, num_outputs, _ = features.shape
    window_size = self.window_size
    targets   = targets.view(num_samples, num_outputs, -1, window_size)
    features  = features.view(num_samples, num_inputs, -1, window_size)

    print("Features ~ (samples, outputs, windows, window size) = " +str(features.shape))
    print("Targets ~ (samples, inputs, windows, window size) = " +str(targets.shape))

    #Train
    H = self.calculateHiddenLayerActivation(features)
    Ht = H.transpose(2, 3)
    if self.RLS:
      #Flatten
      H = H.view(-1, num_inputs, window_size)
      Ht = Ht.view(-1, window_size, num_inputs)
      targets = targets.view(-1, num_outputs, window_size)
      #Compute
      self.beta, self.M = self.rls_torch.compute_recursive_least_squares(targets, H, Ht)
    else:
      print("non RLS")
      print("non RLS")
      print("targets ~ " + str(targets.shape))
      print("H ~ " + str(H.shape))
      print("Ht ~ " + str(Ht.shape))
      targets = targets.view(-1, num_outputs, window_size)
      self.M    = self.compute_inverse_covariance_matrix(targets, H, Ht, num_windows)
      self.beta = self.compute_coefficients(targets, H, Ht)
    self.fprint("FOSELM:Train:END -->", self.print_flag)
    """
  
  def forward(self, features): #Predict
    """
    Make prediction with feature matrix
    :param features: feature matrix with dimension (num_samples, num_inputs, num_timesteps)
    :return: predictions with dimension (num_samples, num_outputs, num_timesteps)
    """
    (_, num_inputs, )  = features.shape 
    assert num_inputs == self.inputs, \
      print ("FOSELM ~ Invalid number of inputs for the model features ~ ", features.shape, "num_inputs", num_inputs)
    

    self.fprint("--> FOSELM: Prediction", self.print_flag)
    H = self.calculateHiddenLayerActivation(features)
    self.fprint("FOSELM --> Just before prediction", self.print_flag)
    prediction = torch.matmul(H, self.beta)
    self.fprint("FOSELM: Prediction -->", self.print_flag)

    return prediction
