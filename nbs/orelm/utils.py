import torch
from nbs.orelm.foselm_torch import FOSELM_torch


def linear_recurrent(features, inputW,hiddenW,hiddenA, bias, print_flag = True):
    if (print_flag):
        print("---> Linear_recurrent")
        (numSamples, numInputs) = features.shape
        (numHiddenNeuron, numInputs) = inputW.shape
        print("numSamples: " + str(numSamples))
        print("numInputs: " + str(numInputs))
        print("numHiddenNeuron: " + str(numHiddenNeuron))
        print("Features = (samples, inputs): " + str(features.shape))
        print("NumInputs = (hidden, inputs): " + str(inputW.shape))
    V = torch.mm(features, inputW.t()) + torch.mm(hiddenA, hiddenW) + bias
    if (print_flag):
       print("Linear_recurrent --->")
    return V

def sigmoidActFunc(V, printFlag=True):
    if printFlag:
        print("--> SigmoidActFunc")
    H = 1 / (1 + torch.exp(-V))
    return H

def spacing_torch(S):
    dtype = S.dtype
    if dtype == torch.float16:
        return S * 2.0 ** -10
    elif dtype == torch.float32:
        return S * 2.0 ** -23
    elif dtype == torch.float64:
        return S * 2.0 ** -52
    else:
        # Agregar manejo para otros tipos de datos si es necesario
        raise ValueError("Tipo de dato no soportado: {}".format(dtype))

def orthogonalization(Arr):
    """
    Arr: Matriz (torch.Tensor)
    Q:   Resultado (torch.Tensor)
    """
    U, S, V = torch.svd(Arr)
    tol = spacing_torch(S)
    r = torch.sum(S > tol)
    Q = U[:, :r]
    return Q

def linear(features, weights, bias, print_flag=True):
    assert features.shape[1] == weights.shape[1], \
        "features shape (" + str(features.shape[1]) + ") must be equal to weights shape (" + str(weights.shape[1]) + ")"
    if print_flag:
        numSamples, numInputs = features.shape
        numHiddenNeuron, numInputs = weights.shape
        print("Features ~ (numSamples, numInputs) = ", numSamples, numInputs)
        print("Weights ~ (numHiddenNeuron, numInputs) = ", numHiddenNeuron, numInputs)
    V = torch.mm(features, weights.t()) + bias
    return V


