from tsai.all import *
import os
import sys

lib_orelm_path = os.path.expanduser("~/lib/orelm/")
sys.path.append(lib_orelm_path)
print(lib_orelm_path)
if os.path.exists(lib_orelm_path):
    print("El directorio existe:", lib_orelm_path)
else:
    print("El directorio no existe:", lib_orelm_path)

sys.path = [path for path in sys.path if path != lib_orelm_path]
print(sys.path)
if lib_orelm_path not in sys.path:
    sys.path.append(lib_orelm_path)
print(sys.path)
import algorithms.OR_ELM as orelm
import algorithms.FOS_ELM as foselm

class ORELM_torch(Module):
    def valid_parameters(self, inputs, outputs, numHiddenNeurons, activationFunction, LN,AE, ORTH, inputWeightForgettingFactor, outputWeightForgettingFactor):
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

    def __init__(self, 
      inputs, 
      outputs, 
      numHiddenNeurons, 
      activationFunction = "sig", #? Must always be "sig"
      LN    = True,  #? - Layer normalization boolean
      AE    = True,  #? - Para Alaiñe, siempre es True
      ORTH  = True, 
      inputWeightForgettingFactor   = 0.999,
      outputWeightForgettingFactor  = 0.999,
    ): 
        self.valid_parameters(inputs, outputs, numHiddenNeurons, activationFunction, LN,AE, ORTH, inputWeightForgettingFactor, outputWeightForgettingFactor)    
        self.activationFunction = activationFunction #?
        self.outputs = outputs
        self.numHiddenNeurons = numHiddenNeurons
        self.inputs = inputs
        # input to hidden weights
        print("("+str(self.numHiddenNeurons) +", "+ str(self.inputs)+")")
        self.inputWeights  = np.random.random((self.numHiddenNeurons, self.inputs))
        # hidden layer to hidden layer wieghts
        self.hiddenWeights = np.random.random((self.numHiddenNeurons, self.numHiddenNeurons))
        
        # initial hidden layer activation
        self.initial_H  = np.random.random((1, self.numHiddenNeurons)) * 2 -1
        self.H          = self.initial_H
        self.LN         = LN #?
        self.AE         = AE #? 
        self.ORTH       = ORTH
        
        # bias of hidden units
        self.bias = np.random.random((1, self.numHiddenNeurons)) * 2 - 1
        
        # hidden to output layer connection
        self.beta = np.random.random((self.numHiddenNeurons, self.outputs))

        # auxiliary matrix used for sequential learning
        self.M = orelm.inv(0.00001 * np.eye(self.numHiddenNeurons)) #eye: diagonal, inv: inverse

        self.forgettingFactor       = outputWeightForgettingFactor
        self.inputForgettingFactor  = inputWeightForgettingFactor

        self.trace      = 0
        self.thresReset = 0.001


        if self.AE: #En OTSAD -> directamente FOSELM
            self.inputAE = foselm.FOSELM(
                inputs              = inputs,
                outputs             = inputs,
                numHiddenNeurons    = numHiddenNeurons,
                activationFunction  = activationFunction, #?
                LN                  = LN, #?
                forgettingFactor    = inputWeightForgettingFactor,
                ORTH = ORTH
            )

            self.hiddenAE = foselm.FOSELM(
                inputs = numHiddenNeurons,
                outputs = numHiddenNeurons,
                numHiddenNeurons = numHiddenNeurons,
                activationFunction=activationFunction,#?
                LN= LN,
                ORTH = ORTH
            )

    def layerNormalization(
            self, 
            H, 
            scaleFactor=1, 
            biasFactor=0
        ):
        H_normalized = (H-H.mean())/(np.sqrt(H.var() + 0.000001)) #0.0001
        H_normalized = scaleFactor*H_normalized+biasFactor
        return H_normalized
        
    def __calculateInputWeightsUsingAE(self, features):
        self.inputAE.train(features=features,targets=features)
        return self.inputAE.beta

    def __calculateHiddenWeightsUsingAE(self, features):
        self.hiddenAE.train(features=features,targets=features)
        return self.hiddenAE.beta
    def calculateHiddenLayerActivation(self, features):
        """
        Calculate activation level of the hidden layer
        :param features feature matrix with dimension (numSamples, numInputs)
        :return: activation level (numSamples, numHiddenNeurons)
        """
        #? Este paso lo quita Alaiñe... porque sólo está implementada la opción de "sig"
        if self.activationFunction == "sig": 
            if self.AE:
                self.inputWeights = self.__calculateInputWeightsUsingAE(features)
                self.hiddenWeights = self.__calculateHiddenWeightsUsingAE(self.H)
            V = orelm.linear_recurrent(
                features    = features,
                inputW      = self.inputWeights,
                hiddenW     = self.hiddenWeights,
                hiddenA     = self.H,
                bias        = self.bias
            )
            if self.LN: #? -> Aqui es siempre true para Alaiñe
                V = self.layerNormalization(V)
            self.H = orelm.sigmoidActFunc(V)
        else:
            print ("Unknown activation function type: " + self.activationFunction )
            raise NotImplementedError
        return self.H
    
    def initializePhase(self, lamb=0.0001):
        """
        Step 1: Initialization phase
        :param features feature matrix with dimension (numSamples, numInputs)
        :param targets target matrix with dimension (numSamples, numOutputs)
        """
        if self.activationFunction == "sig":
            self.bias = np.random.random((1, self.numHiddenNeurons)) * 2 - 1
        else:
            print (" Unknown activation function type: " + self.activationFunction)
            raise NotImplementedError   
    
        self.M      = orelm.inv(lamb*np.eye(self.numHiddenNeurons))
        self.beta   = np.zeros([self.numHiddenNeurons,self.outputs])
        
        # randomly initialize the input->hidden connections
        self.inputWeights = np.random.random((self.numHiddenNeurons, self.inputs))
        self.inputWeights = self.inputWeights * 2 - 1
        
        if self.AE:
            self.inputAE.initializePhase(lamb=0.00001)
            self.hiddenAE.initializePhase(lamb=0.00001)
        else:
            # randomly initialize the input->hidden connections
            self.inputWeights = np.random.random((self.numHiddenNeurons, self.inputs))
            self.inputWeights = self.inputWeights * 2 - 1
        # ... ? Esta parte no está en Alaiñe
        if self.ORTH: 
            if self.numHiddenNeurons > self.inputs:
                self.inputWeights = orelm.orthogonalization(self.inputWeights)
        else:
            self.inputWeights = orelm.orthogonalization(self.inputWeights.transpose())
            self.inputWeights = self.inputWeights.transpose()
        # hidden layer to hidden layer wieghts
        self.hiddenWeights = np.random.random((self.numHiddenNeurons, self.numHiddenNeurons))
        self.hiddenWeights = self.hiddenWeights * 2 - 1
        if self.ORTH:
            self.hiddenWeights = orelm.orthogonalization(self.hiddenWeights)
        #? ...
    def reset(self):#?
        self.H = self.initial_H
    def train(self, features, targets,RESETTING=False):
        """
        Step 2: Sequential learning phase
        :param features feature matrix with dimension (numSamples, numInputs)
        :param targets target matrix with dimension (numSamples, numOutputs)
        """
        (numSamples, numOutputs) = targets.shape
        assert (features.shape[0] == targets.shape[0]), \
            "Number of columns of features and weights differ"
        H = self.calculateHiddenLayerActivation(features)
        Ht = np.transpose(H)
        try:
            scale = 1/(self.forgettingFactor)
            aux = scale * self.M
            self.M = aux -  np.dot(aux,
                                np.dot(Ht, np.dot(
                                    orelm.pinv(np.eye(numSamples) + np.dot(H, np.dot(aux, Ht))),
                                    np.dot(H, aux)
                                    )
                                )
                            )
            #...? Fañta en el trozo de Alaiñe
            if RESETTING:
                beforeTrace=self.trace
                self.trace=self.M.trace()
                print (np.abs(beforeTrace - self.trace))
                if np.abs(beforeTrace - self.trace) < self.thresReset:
                    print (self.M)
                    eig,_=np.linalg.eig(self.M)
                    lambMin=min(eig)
                    lambMax=max(eig)
                    #lamb = (lambMax+lambMin)/2
                    lamb = lambMax
                    lamb = lamb.real
                    self.M= lamb*np.eye(self.numHiddenNeurons)
                    print ("reset")
                    print (self.M)
            #? ...
            aux = self.forgettingFactor*self.beta
            self.beta = aux +   np.dot(
                                    self.M, 
                                    np.dot(Ht, targets - np.dot(H, aux))
                                )
        except np.linalg.linalg.LinAlgError:
            print ("SVD not converge, ignore the current training cycle")
    
    def predict(self, features):
        """
        Make prediction with feature matrix
        :param features: feature matrix with dimension (numSamples, numInputs)
        :return: predictions with dimension (numSamples, numOutputs)
        """
        H = self.calculateHiddenLayerActivation(features)
        prediction = np.dot(H, self.beta)
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