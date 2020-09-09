# AUTOGENERATED! DO NOT EDIT! File to edit: nbs/00_load.ipynb (unless otherwise specified).

__all__ = ['fpreprocess_numeric_vars', 'fread_and_concat', 'fread_mining_monitoring_files', 'TSArtifact',
           'create_longwall_data_artifact', 'load_longwall_data_artifact', 'slices2array', 'fmultiTSloader']

# Cell
import pandas as pd
import numpy as np
from fastcore.all import *
import wandb
from datetime import datetime, timedelta
from .utils import *

# Cell
def fpreprocess_numeric_vars(data, cname_ts=None, normalize=True, nan_replacement=0):
    "Preprocess a dataframe `data` containing the monitoring data from a mining longwall. \
    Non-numeric variables will be removed. Each column \
    is expected to have values of a variable in form of a time series, whose index will be described in the \
    column named `cname_ts`. If `cname_ts` is None (default), the index of the dataframe is assumed to contain the \
    timestamps. .NaN values will be \
    replaced by a constant value `nan_replacement`"
    if cname_ts is not None:
        data.index = pd.to_datetime(data[cname_ts])
        data = data.drop(cname_ts, axis=1)
    df1 = data.select_dtypes(exclude='object')
    df2 = data.select_dtypes(include='object').astype('bool')
    data = pd.concat([df2, df1], axis = 1)
    data_numeric = data.select_dtypes(include=['float', 'datetime'])
    tmp = data_numeric.select_dtypes(include='float')
    if normalize: data_numeric[data_numeric.select_dtypes(include='float').columns] = (tmp - tmp.min())/(tmp.max()-tmp.min())
    data_numeric = data_numeric.dropna(axis=1, how='all').fillna(nan_replacement)
    return data_numeric

# Cell
def fread_and_concat(paths, **read_args):
    "Read, from `paths`, a list of mining dataframes and concat them. All dataframes \
    must have the same columns. "
    return pd.concat([pd.read_csv(x, **read_args) for x in paths],
                     ignore_index=True)

# Cell
def fread_mining_monitoring_files(paths, **kwargs):
    "Read monitoring files from the PACMEL mining use case."
    df = fread_and_concat(paths,
                          sep=';',
                          low_memory=False,
                          skiprows=2,
                          **kwargs)
    # Convert the timestamp column into a proper datetime object
    df['description'] = pd.to_datetime(df['description'])
    return df

# Cell
class TSArtifact(wandb.Artifact):
    default_storage_path = Path('/data/PACMEL-2019/wandb_artifacts/')
    date_format = '%Y-%m-%d %H:%M:%S' # TODO add milliseconds

    "Class that represents a wandb artifact containing time series data. sd stands for start_date \
    and ed for end_date. Both should be pd.Timestamps"
    @delegates(wandb.Artifact.__init__)
    def __init__(self, name, sd:pd.Timestamp=None, ed:pd.Timestamp=None, **kwargs):
        super().__init__(type='dataset', name=name, **kwargs)
        self.sd = sd
        self.ed = ed
        if self.metadata is None:
            self.metadata = dict()
        self.metadata['TS'] = dict(sd = self.sd.strftime(self.date_format),
                                   ed = self.ed.strftime(self.date_format))

    @classmethod
    def from_daily_csv_files(cls, root_path, fread=pd.read_csv, start_date=None, end_date=None, metadata=None, **kwargs):
        "Create a wandb artifact of type `dataset`, containing the CSV files from `start_date` \
        to `end_date`. Dates must be pased as `datetime.datetime` objects. If a `wandb_run` is \
        defined, the created artifact will be logged to that run, using the longwall name as \
        artifact name, and the date range as version."
        return None

    @classmethod
    @delegates(__init__)
    def from_df(cls, df, name, path=None, sd=None, ed=None, normalize=False, **kwargs):
        "Stores the dataframe `df` as a pickle file in the pat `path` and adds its reference \
        to the entries of the artifact."
        sd = df.index[0] if sd is None else sd
        ed = df.index[-1] if ed is None else ed
        obj = cls(name, sd=sd, ed=ed, **kwargs)
        df = df.query('index >= @obj.sd') if obj.sd is not None else df
        df = df.query('index <= @obj.ed') if obj.ed is not None else df

        obj.metadata['TS']['created'] = 'from-df'
        obj.metadata['TS']['freq'] = str(df.index.freq)
        obj.metadata['TS']['n_vars'] = df.columns.__len__()
        obj.metadata['TS']['n_samples'] = len(df)
        obj.metadata['TS']['has_missing_values'] = np.any(df.isna().values).__str__()
        obj.metadata['TS']['vars'] = list(df.columns)
        # Normalization - Save the previous means and stds
        if normalize:
            obj.metadata['TS']['normalization'] = dict(
                means = df.describe().loc['mean'].to_dict(),
                stds = df.describe().loc['std'].to_dict()
            )
            df = normalize_columns(df)
        # Hash and save
        hash_code = str(hash(df.values.tobytes()))
        path = obj.default_storage_path/f'{hash_code}' if path is None else Path(path)/f'{hash_code}'
        df.to_pickle(path)
        obj.metadata['TS']['hash'] = hash_code
        obj.add_file(path)
        return obj

# Cell
@patch
def to_df(self:wandb.apis.public.Artifact):
    "Download the files of a saved wandb artifact and process them as a single dataframe. The artifact must \
    come from a call to `run.use_artifact` with a proper wand run."
    # The way we have to ensure that the argument comes from a TS arfitact is the metadata
    if self.metadata.get('TS') is None:
        print(f'ERROR:{self} does not come from a logged TSArtifact')
        return None
    dir = Path(self.download())
    if self.metadata['TS']['created'] == 'from-df':
        # Call read_pickle with the single file from dir
        return pd.read_pickle(dir.ls()[0])
    else:
        print("ERROR: Only from_df method is allowed yet")

# Cell
@patch
def to_tsartifact(self:wandb.apis.public.Artifact):
    "Cast an artifact as a TS artifact. The artifact must have been created from one of the \
    class creation methods of the class `TSArtifact`. This is useful to go back to a TSArtifact \
    after downloading an artifact through the wand API"
    return TSArtifact(name=self.digest, #TODO change this
                      sd=pd.to_datetime(self.metadata['TS']['sd'], format=TSArtifact.date_format),
                      ed=pd.to_datetime(self.metadata['TS']['sd'], format=TSArtifact.date_format),
                      description=self.description,
                      metadata=self.metadata)

# Cell
def create_longwall_data_artifact(root_path, start_date, end_date, longwall_name='Unnamed_longwall', wandb_run=None):
    "Create a wandb artifact of type `dataset`, containing the CSV files from `start_date` \
    to `end_date`. Dates must be pased as `datetime.datetime` objects. If a `wandb_run` is \
    defined, the created artifact will be logged to that run, using the longwall name as \
    artifact name, and the date range as version."
    # Compute the number of variables for the metadata (total and numeric)
    root_path = Path(root_path)
    date_diff = end_date - start_date
    sd_str = start_date.strftime("%Y-%m-%d")
    ed_str = end_date.strftime("%Y-%m-%d")
    mock_data = fread_mining_monitoring_files([f'{root_path/start_date.strftime("%Y-%m-%d")}.csv'],
                                             nrows=1)
    artifact_name = longwall_name if longwall_name else root_path
    artifact = wandb.Artifact(type='dataset',
                              name=artifact_name,
                              description='Dataset from the PACMEL mining use case. It contains \
                              monitoring data from a longwall shearer',
                              metadata={
                              'longwall': longwall_name,
                              'start_time': datetime.strftime(start_date, format='%Y-%m-%d %H:%M:%S'),
                              'end_time': datetime.strftime(end_date, format='%Y-%m-%d %H:%M:%S'),
                              'n_variables': len(mock_data.columns)-1 # Exclude timestamp
                              })
    # ADd files as references (we do not upload files for confidential reasons)
    [artifact.add_reference(f'file://{root_path/x.strftime("%Y-%m-%d")}.csv')
     for x in (start_date + timedelta(days=n) for n in range(date_diff.days + 1))]

    if wandb_run:
        artifact_version = f'{sd_str}_{ed_str}'
        wandb_run.log_artifact(artifact,
                               aliases=['latest', artifact_version])
    return artifact

# Cell
def load_longwall_data_artifact(a:wandb.Artifact):
    "Returns a dataframe with the longwall data, subsetted by the artifact metadata"
    a_refs = [x.ref for x in a.manifest.entries.values()]
    data = fread_mining_monitoring_files(a_refs)
    sd = datetime.strptime(a.metadata['start_time'], '%Y-%m-%d %H:%M:%S')
    ed = datetime.strptime(a.metadata['end_time'], '%Y-%m-%d %H:%M:%S')
    data = data.query('description >= @sd and description <= @ed')
    return data

# Comes from 02_DCAE.ipynb, cell
def slices2array(slices):
    "`slices` is a list of dataframes, each of them containing an slice of a multivariate time series."
    return np.rollaxis(np.dstack([x.values for x in slices]), -1)

# Comes from 02_DCAE.ipynb, cell
def fmultiTSloader(df, w, stride, **kwargs):
    "Preprocess a dataframe with multivariate time series from a df `df` or from set of paths `paths`, \
    preprocess it calling `fpreprocess_numeric_vars` \
    slice it into time windows of length `w` and stride `stride` calling `fslicer`, and \
    conert the result into a numpy array, suitable for ML libraries. Optional arguments for \
    the intermediate functions can be passed through `**kwargs`"
    df_slices = fslicer(df, w, stride)
    array_slices = slices2array([x for x in df_slices])
    return (df, df_slices, array_slices)