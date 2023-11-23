# -*- coding: utf-8 -*-
"""encoder.ipynb

Automatically generated.

Original file is located at:
    /home/macu/work/nbs/encoder.ipynb
"""

#default_exp encoder

#hide
#%load_ext autoreload --> Not working TODO:REVISAR
# %autoreload 2 

#export
import pandas as pd
import numpy as np
from fastcore.all import *
from tsai.callback.MVP import *
from tsai.imports import *
from tsai.models.InceptionTimePlus import InceptionTimePlus
from tsai.models.explainability import get_acts_and_grads
from tsai.models.layers import *
from tsai.data.validation import combine_split_data

#hide
from tsai.all import *

#export 
class DCAE_torch(Module):
    def __init__(self, c_in, seq_len, delta, nfs=[64, 32, 12], kss=[10, 5, 5],
                 pool_szs=[2,2,3], output_fsz=10):
        """
        Create a Deep Convolutional Autoencoder for multivariate time series of `d` dimensions,
        sliced with a window size of `w`. The parameter `delta` sets the number of latent features that will be
        contained in the Dense layer of the network. The the number of features
        maps (filters), the filter size and the pool size can also be adjusted."
        """
        assert all_equal([len(x) for x in [nfs, kss, pool_szs]], np.repeat(len(nfs), 3)), \
            'nfs, kss, and pool_szs must have the same length'
        assert np.prod(pool_szs) == nfs[-1], \
            'The number of filters in the last conv layer must be equal to the product of pool sizes'
        assert seq_len % np.prod(pool_szs) == 0, \
            'The product of pool sizes must be a divisor of the window size'
        layers = []
        for i in range_of(kss):
            layers += [Conv1d(ni=nfs[i-1] if i>0 else c_in, nf=nfs[i], ks=kss[i]),
                       nn.MaxPool1d(kernel_size=pool_szs[i])]
        self.downsample = nn.Sequential(*layers)
        self.bottleneck = nn.Sequential(OrderedDict([
            ('flatten', nn.Flatten()),
            ('latent_in', nn.Linear(seq_len, delta)),
            ('latent_out', nn.Linear(delta, seq_len)),
            ('reshape', Reshape(nfs[-1], seq_len // np.prod(pool_szs)))
        ]))
        layers = []
        for i in reversed(range_of(kss)):
            layers += [Conv1d(ni=nfs[i+1] if i != (len(nfs)-1) else nfs[-1],
                              nf=nfs[i], ks=kss[i]),
                       nn.Upsample(scale_factor=pool_szs[i])]
        layers += [Conv1d(ni=nfs[0], nf=c_in, kernel_size=output_fsz)]
        self.upsample = nn.Sequential(*layers)

    def forward(self, x):
        x = self.downsample(x)
        x = self.bottleneck(x)
        x = self.upsample(x)
        return x

#export
ENCODER_EMBS_MODULE_NAME = {
    InceptionTimePlus: 'backbone', # for mvp based models
    DCAE_torch: 'bottleneck.latent_in'
}

#export
def get_enc_embs(X, enc_learn, module=None, cpu=False, average_seq_dim=True, to_numpy=True):
    """
        Get the embeddings of X from an encoder, passed in `enc_learn as a fastai
        learner. By default, the embeddings are obtained from the last layer
        before the model head, although any layer can be passed to `model`.
        Input
        - `cpu`: Whether to do the model inference in cpu of gpu (GPU recommended)
        - `average_seq_dim`: Whether to aggregate the embeddings in the sequence dimensions
        - `to_numpy`: Whether to return the result as a numpy array (if false returns a tensor)
    """
    print("--> Check CUDA")
    if cpu:
        print("--> Get enc embs CPU")
        enc_learn.dls.cpu()
        enc_learn.cpu()
    else:
        print("--> Ensure empty cache")
        torch.cuda.empty_cache()
        print("--> Use CUDA |Get enc embs GPU ")
        enc_learn.dls.cuda()
        enc_learn.cuda()
        if torch.cuda.is_available():
            print("CUDA está disponible")
            print("Dispositivo CUDA actual: ", torch.cuda.current_device())
            print("Nombre del dispositivo CUDA actual: ", torch.cuda.get_device_name(torch.cuda.current_device()))

        else:
            print("CUDA no está disponible ")
            print("Use CUDA -->")
    if enc_learn.dls.bs == 0: enc_learn.dls.bs = 64

    print("--> Set dataset from X (enc_learn does not contain dls)")
    aux_dl = enc_learn.dls.valid.new_dl(X=X)
    aux_dl.bs = enc_learn.dls.bs if enc_learn.dls.bs>0 else 64
    print("--> Get module")
    module = nested_attr(enc_learn.model,ENCODER_EMBS_MODULE_NAME[type(enc_learn.model)]) if module is None else module

    print("--> Get enc embs bs: ", aux_dl.bs)
    embs = [
        get_acts_and_grads(
            model=enc_learn.model,
            modules=module,
            x=xb[0], 
            cpu=cpu
        )[0] 
        for xb in aux_dl
    ]
    print("--> Concat")
    if not cpu:
        total_emb_size = sum([emb.element_size() * emb.nelement() for emb in embs])
        free_memory = torch.cuda.get_device_properties(0).total_memory - torch.cuda.memory_allocated()
        if (total_emb_size < free_memory):
            print("Fit in GPU")
            embs=[emb.cuda() for emb in embs]
        else:
            print("Dont fit in GPU --> Go to CPU")
            embs=[emb.cpu() for emb in embs]
    embs = to_concat(embs)
    print("--> reduce")
    if embs.ndim == 3 and average_seq_dim: embs = embs.mean(axis=2)
    print("--> 2 numpy")
    if to_numpy: embs = embs.numpy() if cpu else embs.cpu().numpy()
    return embs