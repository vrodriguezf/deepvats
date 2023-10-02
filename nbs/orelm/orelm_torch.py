from tsai.all import *
from nbs.orelm.utils import *
from nbs.orelm.foselm_torch import *
from nbs.orelm.linear_recurrent import *
import nbs.orelm.elm_torch as elm
import nbs.orelm.mse_loss_i as mse
import os
import sys

class ORELM_torch(elm.ELM_torch):
    def valid_parameters(self, inputs, outputs, numHiddenNeurons, activationFunction, LN,AE, ORTH, inputWeightForgettingFactor, outputWeightForgettingFactor, seq_len):
        assert isinstance(inputs, (int, float)) and inputs >= 1, \
          'inputs must be numeric and greater than or equal to 1'
        assert isinstance(outputs, (int, float)) and outputs >= 1, \
          'outputs must be numeric and greater than or equal to 1'
        assert isinstance(numHiddenNeurons, (int, float)) and numHiddenNeurons >= 1, \
          'numHiddenNeurons must be numeric and greater than or equal to 1'
        assert isinstance(ORTH, bool), \
          'orth must be a logical value'
        assert isinstance(inputWeightForgettingFactor, (int, float)) and 0 < inputWeightForgettingFactor <= 1, \
          'inputWeightForgettingFactor must be numeric between 0 and 1'
        assert isinstance(outputWeightForgettingFactor, (int, float)) and 0 < outputWeightForgettingFactor <= 1, \
          'outputWeightForgettingFactor must be numeric between 0 and 1'
        assert seq_len > 0, \
            'Sequence len (seq_len) must be bigger than 0'

    def __init__(
        self, 
        inputs, 
        outputs, 
        numHiddenNeurons, 
        activationFunction = "sig", #? Must always be "sig"
        LN    = True,  #? - Layer normalization boolean
        AE    = True,  #? - Para Alaiñe, siempre es True
        ORTH  = True, 
        inputWeightForgettingFactor   = 0.999,
        outputWeightForgettingFactor  = 0.999,
        seq_len = 1,
    ): 
        super().__init__(inputs, outputs, numHiddenNeurons)
        self.valid_parameters(inputs, outputs, numHiddenNeurons, activationFunction, LN,AE, ORTH, inputWeightForgettingFactor, outputWeightForgettingFactor, seq_len)
        print("inputs: " + str(inputs))
        print("outputs: " + str(outputs))
        print("numNeurons: " + str(numHiddenNeurons))
        print("Out weight FF: " + str(outputWeightForgettingFactor))
        print("Window size: " + str(seq_len))
        
        self.initialized = 0
        
        self.activationFunction = activationFunction #?
        self.outputs            = outputs
        self.numHiddenNeurons   = numHiddenNeurons
        self.inputs             = inputs
        self.window_size        = seq_len

        # input to hidden weights
        print("("+str(self.numHiddenNeurons) +", "+ str(self.inputs)+")")
        self.get_random_InputWeights()
        # hidden layer to hidden layer wieghts
        self.get_random_HiddenWeights()
    
        # initial hidden layer activation
        self.initial_H  = self.get_random_matrix(1, self.numHiddenNeurons) * 2 - 1
        self.H          = self.initial_H
        
        print("orelm-H ~ ", self.H.shape)
        self.LN         = LN #?
        self.AE         = AE #? 
        self.ORTH       = ORTH
        
        # bias of hidden units
        self.get_random_Bias()
        # hidden to output layer connection
        self.beta = self.get_random_matrix(self.numHiddenNeurons, self.outputs)
        
        # auxiliary matrix used for sequential learning
        self.M = torch.inverse(0.00001 * torch.eye(self.numHiddenNeurons)) #eye: diagonal, inv: inverse
        
        self.forgettingFactor       = outputWeightForgettingFactor
        self.inputForgettingFactor  = inputWeightForgettingFactor

        self.trace      = 0
        self.thresReset = 0.001
        print("-------- num_inputs, window_size = " + str(self.inputs) + "," + str(self.window_size))

        if self.AE: #En OTSAD -> directamente FOSELM
            self.inputAE = FOSELM_torch(
                inputs              = inputs,
                outputs             = inputs,
                numHiddenNeurons    = numHiddenNeurons,
                activationFunction  = activationFunction, #?
                LN                  = LN, #?
                forgettingFactor    = inputWeightForgettingFactor,
                ORTH = ORTH,
                seq_len = self.window_size
            )

            print("input FOSELM model", self.inputAE)
            print("input, output" ,self.inputAE.inputs, self.inputAE.outputs)

            
            self.hiddenAE = FOSELM_torch(
                inputs              = numHiddenNeurons,
                outputs             = numHiddenNeurons,
                numHiddenNeurons    = numHiddenNeurons,
                activationFunction  = activationFunction,#?
                LN                  = LN,
                ORTH                = ORTH,
                seq_len             = self.window_size
            )

            print("Output FOSELM model", self.hiddenAE)
            print("input, output", self.hiddenAE.inputs, self.hiddenAE.outputs)
        
    def __calculateInputWeightsUsingAE(self, features):
        print("--> Input AE")
        self.inputAE.train_func(features=features,targets=features)
        print("Input AE -->")
        return self.inputAE.beta

    def __calculateHiddenWeightsUsingAE(self, features):
        print("--> Hidden AE")
        self.hiddenAE.train_func(features=features,targets=features)
        print("Hidden AE -->")
        return self.hiddenAE.beta
    
    def calculateHiddenLayerActivation(self, features, flag_debug=0):
        """
        Calculate activation level of the hidden layer
        :param features feature matrix with dimension (numSamples, numInputs) #Aqui se añade numWindows
        :return: activation level (numSamples, numHiddenNeurons)
        """
        #? Este paso lo quita Alaiñe... porque sólo está implementada la opción de "sig"
        if self.activationFunction == "sig": 
            if self.AE:
                self.inputWeights = self.__calculateInputWeightsUsingAE(features)
                print("Features ~ ", features.shape)
                num_samples = features.shape[0]
                self.H = torch.zeros(num_samples, self.numHiddenNeurons, self.numHiddenNeurons)
                for i in range(num_samples):
                    self.H[i]  = self.get_random_matrix(1, self.numHiddenNeurons) * 2 - 1
                print("orelm-H ~ ", self.H.shape)
                self.hiddenWeights = self.__calculateHiddenWeightsUsingAE(self.H)
            self.fprint("Before LR " + str(flag_debug) + ": " + str(features.shape), self.print_flag)
            #Linear recurrent RNN layer setup
            hidden_size = self.numHiddenNeurons     
            input_size  = hidden_size #self.inputs 
            numLayers   =1                  #Num Linear Recurrent layers
            batch_size = features.shape[0]  #numSamples
            #Create layer
            self.fprint("Create layer", self.print_flag)
            lr_layer  = nn.RNN(input_size,hidden_size,numLayers,bias=True, batch_first=True)
            #Setup bias matrices
            self.fprint("Setup bias", self.print_flag)
            lr_layer.bias_ih_l0 = nn.Parameter(self.bias)
            lr_layer.bias_hh_l0 = nn.Parameter(self.bias)
            #Create tensor for initial hiddenState
            #lr_initial_hidden_state = torch.zeros(numLayers, batch_size, self.numHiddenNeurons)  
            lr_initial_hidden_state = torch.zeros(numLayers, batch_size, features.shape[2])  
            self.fprint("Apply LR layer", self.print_flag)
            self.fprint("features ~ " + str(features.shape), self.print_flag)
            self.fprint("Lr initial hidden state ~ " + str(lr_initial_hidden_state.shape), self.print_flag)
            lr_output, lr_new_hidden_state = lr_layer(features, lr_initial_hidden_state)
            #lr_layer = linear_recurrent(features    = features,inputW      = self.inputWeights,hiddenW     = self.hiddenWeights, hiddenA     = self.H, bias        = self.bias)
            #Layer normalization
            if self.LN: #? -> Aqui es siempre true para Alaiñe
                #Batch normalization
                self.fprint("ORELM: Create normalization layer", self.print_flag)
                ln_layer  = self.get_ln_layer(lr_output)
                self.fprint("ORELM: Normalize lr output", self.print_flag)
                lr_output = ln_layer(lr_output)
            #Layer activation
            self.fprint("Get hidden layer activation", self.print_flag)
            self.H = torch.sigmoid(lr_output)
            print("orelm-H ~ ", self.H.shape)
        else:
            print ("Unknown activation function type: " + self.activationFunction )
            raise NotImplementedError
        print("ORELM: calculate hidden layer activation "+str(flag_debug)+" -->")
        return self.H
    
    def initializePhase(self, lamb=0.0001):
        """
        Step 1: Initialization phase
        :param features feature matrix with dimension (numSamples, numInputs)
        :param targets target matrix with dimension (numSamples, numOutputs)
        """

        if self.activationFunction == "sig":
            self.get_random_Bias()
        else:
            print (" Unknown activation function type: " + self.activationFunction)
            raise NotImplementedError   
    
        self.M      = torch.inverse(lamb*torch.eye(self.numHiddenNeurons))
        self.beta   = torch.zeros([self.numHiddenNeurons,self.outputs])
        
        # randomly initialize the input->hidden connections
        self.get_random_InputWeights()
        self.inputWeights = self.inputWeights * 2 - 1
        print("--> Initialize_Phase: Input Weights initialized. Shape: "+ str(self.inputWeights.shape)) #? 
        if self.AE:
            self.inputAE.initializePhase(lamb=0.00001)
            self.hiddenAE.initializePhase(lamb=0.00001)
        else:
            # randomly initialize the input->hidden connections
            self.get_random_InputWeights()
            self.inputWeights = self.inputWeights*2-1
        # ... ? Esta parte no está en Alaiñe
        if self.ORTH: 
            if self.numHiddenNeurons > self.inputs:
                self.inputWeights = orthogonalization(self.inputWeights)
        else:
            self.inputWeights = orthogonalization(self.inputWeights.t())
            self.inputWeights = self.inputWeights.t()
        # hidden layer to hidden layer weights
        self.get_random_HiddenWeights()
        self.hiddenWeights = self.hiddenWeights *2-1
        if self.ORTH:
            self.hiddenWeights = orthogonalization(self.hiddenWeights)
        #? ...
    def reset(self):#?
        self.H = self.initial_H
    

    
    def train_func(self, features, targets,RESETTING=False):
        """
        Step 2: Sequential learning phase
        :param features feature matrix with dimension (numSamples, numInputs)
        :param targets target matrix with dimension (numSamples, numOutputs)
        """
        sys.stdout.flush()
        (numSamples, numOutputs) = targets.shape
        (numWeights, _) = features.shape
        print("ORELM:TRAIN:samples = weights: " +  str(numSamples) + " | outputs: " + str(numOutputs))
        print("ORELM:TRAIN:Features shape: " + str(features.shape) + "=> Columns: " + str(features.shape[0]))
        print("ORELM:TRAIN:Weights number: " + str(numWeights) + " = " + str(numSamples))
        sys.stdout.flush()
        assert (features.shape[0] == numSamples), \
            "Number of columns of features and weights differ"
        self.fprint("--> Calculate Hidden Activation 1", self.print_flag)
        H = self.calculateHiddenLayerActivation(features, 1)
        self.fprint("Calculate Hidden Activation 1 -->", self.print_flag)
        Ht = H.t()
        try:
            scale = 1/(self.forgettingFactor)
            aux = scale * self.M
            self.M = aux -  torch.mm(aux,
                                torch.mm(Ht, torch.mm(
                                    torch.pinverse(torch.eye(numSamples) + torch.mm(H, torch.mm(aux, Ht))),
                                    torch.mm(H, aux)
                                    )
                                )
                            )
            #...? Falta en el trozo de Alaiñe
            if RESETTING:
                beforeTrace=self.trace
                self.trace=self.M.trace()
                print (torch.abs(beforeTrace - self.trace))
                if torch.abs(beforeTrace - self.trace) < self.thresReset:
                    print (self.M)
                    #eig,_=torch.eig(self.M, eigenvectors=True)
                    eig,_=torch.eig(self.M, eigenvectors=False)
                    lambMin=min(eig)
                    lambMax=max(eig)
                    #lamb = (lambMax+lambMin)/2
                    lamb = lambMax
                    lamb = lamb.real
                    self.M= lamb*torch.eye(self.numHiddenNeurons)
                    print ("reset")
                    print (self.M)
            #? ...
            aux = self.forgettingFactor*self.beta
            self.beta = aux +   torch.mm(
                                    self.M, 
                                    torch.mm(Ht, targets - torch.mm(H, aux))
                                )
        except torch.linalg.LinAlgError:
            print ("SVD not converge, ignore the current training cycle")

        print("ORELM train -->") 
    
    def orelm_splitter(self, model): #Ver cómo escribirlo bien para que no de guerra
        return [list(self.inputAE.parameters()), list(self.hiddenAE.parameters())]
    
    
    def forward(self, features): #Predict
        """
        Make prediction with feature matrix
        :param features: feature matrix with dimension (numSamples, numInputs, time_steps)
        :return: predictions with dimension (numSamples, numOutputs, time_steps)
        """

        self.fprint("--> ORELM Forward", self.print_flag)

        (_, num_inputs, _)  = features.shape 
        assert num_inputs == self.inputs, \
            "FOSELM ~ Invalid number of inputs for the model features ~ " + str(features.shape) + \
                  "num_inputs " + str( num_inputs) 

        self.fprint("--> ORELM Calculate Hidden Activation 3", self.print_flag)
        self.fprint("ORELM Features ~ " + str(features.shape), self.print_flag)
        H = self.calculateHiddenLayerActivation(features,2 )
        self.fprint("ORELM Get prediction", self.print_flag)
        prediction = torch.matmul(H, self.beta)
        self.fprint("ORELM Calculate Hidden Activation 3 --> Features ~ " + str(features.shape), self.print_flag)
        print("ORELM Forward --> result ~ " + str(prediction.shape))
        return prediction        
    
    






def readDataSet(dataSet):
  prefix = '~/lib/orelm/'
  filePath = prefix+'data/'+dataSet+'.csv'
  if dataSet=='nyc_taxi':
    df = pd.read_csv(filePath, header=0, skiprows=[1,2],
                     names=['time', 'data', 'timeofday', 'dayofweek'])
    sequence = df['data']
    dayofweek = df['dayofweek']
    timeofday = df['timeofday']
    seq = pd.DataFrame(np.array(pd.concat([sequence, timeofday, dayofweek], axis=1)),
                        columns=['data', 'timeofday', 'dayofweek'])
  elif dataSet=='sine':
    df = pd.read_csv(filePath, header=0, skiprows=[1, 2], names=['time', 'data'])
    sequence = df['data']
    seq = pd.DataFrame(np.array(sequence), columns=['data'])
  else:
    raise(' unrecognized dataset type ')

  return seq



