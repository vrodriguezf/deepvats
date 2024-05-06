# -*- coding: utf-8 -*-
"""02b_encoder_MVP.ipynb

Automatically generated.

Original file is located at:
    /home/macu/work/nbs_pipeline/02b_encoder_MVP.ipynb
"""

#| export
# + tags=["parameters"]
print_flag                    = False
check_memory_usage            = False
time_flag                     = False
window_size_percentage        = False
show_plots                    = False
reset_kernel                  = True
pre_configured_case           = False
case_id                       = 1
frequency_factor              = 5
frequency_factor_change_alias = True

#| export
# This is only needed if the notebook is run in VSCode
import sys
import dvats.utils as ut
if '--vscode' in sys.argv:
    print("Executing inside vscode")
    ut.DisplayHandle.update = ut.update_patch

#| export
import dvats.config as cfg_

#| export
import warnings
warnings.filterwarnings("ignore", module="umap")
import os
import sys
sys.path.append(os.path.abspath('..'))
from dvats.all import *
from fastcore.all import *
from tsai.basics import *
from tsai.models.InceptionTimePlus import *
from tsai.callback.MVP import *
import matplotlib.colors as colors
from fastai.callback.wandb import WandbCallback
from fastai.callback.progress import ShowGraphCallback
from fastai.callback.schedule import *
from fastai.callback.tracker import EarlyStoppingCallback
import wandb

#| export
wandb_api = wandb.Api()

#| export
cuda_device = torch.cuda.current_device()

#| export
device = torch.device(f'cuda:{cuda_device}' if torch.cuda.is_available() else 'cpu')
torch.cuda.set_device(device)
if check_memory_usage:
    gpu_device = torch.cuda.current_device()
    gpu_memory_status(gpu_device)

#| export
user, project, version, data, config, job_type = cfg_.get_artifact_config_MVP_SWV(False)
if pre_configured_case: 
    cfg_.force_artifact_config_mvp(
        config = config,
        id = case_id,
        print_flag = print_flag, 
        both = print_flag,
        frequency_factor = frequency_factor,
        frequency_factor_change_alias = frequency_factor_change_alias
    )

#| export
path = os.path.expanduser("~/work/nbs_pipeline/")
name="02a_encoder_MVP"
os.environ["WANDB_NOTEBOOK_NAME"] = path+name+".ipynb"
runname=name
if print_flag: print("runname: "+runname)
if print_flag: cfg_.show_attrdict(config)

#| export
if print_flag: print("--> Wandb init")
run = wandb.init(
    entity = user,
    # work-nbs is a place to log draft runs
    project=project,
    group=config.wandb_group,
    job_type=job_type,
    allow_val_change=True,
    mode=config.analysis_mode,
    config=config,
    # When use_wandb is false the run is not linked to a personal account
    #NOTE: This is not working right now
    anonymous = 'never' if config.use_wandb else 'must', 
    resume=False,
    name = runname
)
if print_flag: print("Wandb init -->")
config = run.config  # Object for storing hyperparameters
artifacts_gettr = run.use_artifact if config.use_wandb else wandb_api.artifact

#| export
config = run.config  # Object for storing hyperparameters
if print_flag: cfg_.show_attrdict(config)
artifacts_gettr = run.use_artifact if config.use_wandb else wandb_api.artifact
train_artifact = artifacts_gettr(config.train_artifact)
if print_flag: print("---> W&B Train Artifact")

#| export
df_train = train_artifact.to_df()

#| export
if print_flag: 
    print(df_train.shape)
    display(df_train.head)
    print("df_train ~ ", df_train.shape)
    print("window_sizes = ", config.mvp_ws)
    print("wlen = ", config.w)
    df_train.head

#| export
if print_flag: print("---> Sliding window | ", config.w,  " | ", config.stride )
sw = SlidingWindow(window_len=config.w, stride=config.stride, get_y=[])
if print_flag: print(" Sliding window | ", config.w,  " | ", config.stride, "---> | df_train ~ ", df_train.shape )
X_train, _ = sw(df_train)
if print_flag: print(" sw_df_train | ", config.w,  " | ", config.stride, "--->" )

#| export
assert config.analysis_mode in ['offline','online'], 'Invalid analysis mode'

X = X_train
if print_flag: print("len(X): ", len(X));
if config.analysis_mode == 'online':
    if print_flag: print("--> Split 1")
    splits = TimeSplitter(valid_size=0.2, show_plot=show_plots)(X)
elif config.analysis_mode == 'offline':
    if print_flag: print("--> Split 2")
    splits = get_splits(np.arange(len(X)), valid_size=config.valid_size, show_plot = show_plots)
if print_flag: 
    print("Split -->", len(splits[0]))

#| export
if print_flag: print("--> About to set callbacks")
cbs = L(WandbCallback(log_preds=False)) if config.use_wandb else L()

#| export
if print_flag: print("--> About to set batch tfms")
tfms = [ToFloat(), None]
batch_tfms = [TSStandardize(by_sample=config.norm_by_sample, 
               use_single_batch=config.norm_use_single_batch)]

#| export
dls = get_ts_dls(X, splits=splits, tfms=tfms, bs=config.batch_size, batch_tfms=batch_tfms)
if print_flag: print("get dls -->")

#| export
if not show_plots: #When .py this is the only option that should be available. That's why this is not an 'else' but a exported cell
    print("\t learn | cbs + MVP")
    learn = ts_learner(
        dls, 
        InceptionTimePlus, 
        cbs= cbs + MVP(
            r = config.r, 
            window_size=config.mvp_ws, 
            future_mask = config.mask_future, 
            target_dir='./models', 
            sync = config.mask_sync, 
            stateful = config.mask_stateful,
            fname=f'encoder_MVP'
        ), y_range=[X.min(), X.max()])

if print_flag: print("learn -->")

#| export
expected_window_size = config.mvp_ws

#| export
mvp_cb = learn.cbs.filter(lambda cb: isinstance(cb, MVP))[0]  # Encuentra el callback MVP
obtained_window_size=mvp_cb.window_size

#| export
if (expected_window_size != obtained_window_size):
    raise ValueError("Obtained window_size for MVP training different from expected window size. Check size, ws1 & ws2 parameters in '02b-encoder_MVP.yaml'")
else: 
    print("Obtained window size tuple is the expected one. Continue!")

#| export
if (obtained_window_size[1] < obtained_window_size[0]):
    raise ValueError("Ws2 must be greater than Ws1 as they are the maximun and minimum window size respectively. Please ensure w2 > w1")
else: 
    w_sizes = np.random.randint(obtained_window_size)

#| export
#Get data batch
x = next(iter(dls.train))
if print_flag: print("x", x)
x_data=x[0]
if print_flag: print("Data shape: " + str( x_data.shape))
time_serie_len = x_data.shape[-1]
if print_flag: print("Time serie len: " + str( time_serie_len))
#Just in case
for ws in w_sizes:
    diff = time_serie_len - ws
    if print_flag: print("diff time serie len - ws", diff)
    result = np.random.randint(0, diff)
    if print_flag: print("ws ", ws, "diff", diff, "result",  result)

#| export
if print_flag: print("--> Train")
lr_valley, lr_steep = learn.lr_find(suggest_funcs=(valley, steep), show_plot=show_plots)
learn.fit_one_cycle(n_epoch=config.epochs, lr_max=lr_valley,  cbs=[EarlyStoppingCallback(monitor='valid_loss', min_delta=0.000001, patience=10)])

#| export
if print_flag: print("Train -->")
learn.validate()
if print_flag: print("Validate -->")

#| export
# Log the learner without the datasets
aux_learn = learn.export_and_get()
if config.use_wandb: 
    run.log_artifact(
        ReferenceArtifact(
            aux_learn, 
            f'mvp', 
            type='learner', 
            metadata=dict(run.config)
        ), 
        aliases=config.alias
    )

#| export
if print_flag: print("Artifact logged | About to finish run")
run.finish()

#| export
if print_flag: print("Execution ended")
from dvats.imports import beep
beep(1)