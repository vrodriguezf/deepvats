# AUTOGENERATED! DO NOT EDIT! File to edit: ../nbs/xai.ipynb.

# %% auto 0
__all__ = ['get_embeddings', 'get_dataset', 'umap_parameters', 'get_prjs', 'plot_projections', 'plot_projections_clusters',
           'calculate_cluster_stats', 'anomaly_score', 'detector', 'plot_anomaly_scores_distribution',
           'plot_clusters_with_anomalies', 'update_plot', 'plot_clusters_with_anomalies_interactive_plot',
           'get_df_selected', 'shift_datetime', 'get_anomalies', 'get_anomaly_styles', 'InteractiveAnomalyPlot',
           'plot_save', 'plot_initial_config', 'ts_plot_interactive']

# %% ../nbs/xai.ipynb 1
#Weight & Biases
import wandb

#Yaml
from yaml import load, FullLoader

#Embeddings
from .all import *
from tsai.data.preparation import prepare_forecasting_data
from tsai.data.validation import get_forecasting_splits
from fastcore.all import *

#Dimensionality reduction
from tsai.imports import *

#Clustering
import hdbscan
import time
from .dr import get_PCA_prjs, get_UMAP_prjs, get_TSNE_prjs

import seaborn as sns
import matplotlib.pyplot as plt
import pandas as pd
import ipywidgets as widgets
from IPython.display import display
from functools import partial

from IPython.display import display, clear_output, HTML as IPHTML
from ipywidgets import Button, Output, VBox, HBox, HTML, Layout, FloatSlider

import plotly.graph_objs as go
import plotly.offline as py
import plotly.io as pio
#! pip install kaleido
import kaleido


# %% ../nbs/xai.ipynb 4
def get_embeddings(config_lrp, run_lrp, api, print_flag = False):
    artifacts_gettr = run_lrp.use_artifact if config_lrp.use_wandb else api.artifact
    emb_artifact = artifacts_gettr(config_lrp.emb_artifact, type='embeddings')
    if print_flag: print(emb_artifact.name)
    emb_config = emb_artifact.logged_by().config
    return emb_artifact.to_obj(), emb_artifact, emb_config

# %% ../nbs/xai.ipynb 5
def get_dataset(
    config_lrp, 
    config_emb,
    config_dr,
    run_lrp,
    api, 
    print_flag = False
):
    # Botch to use artifacts offline
    artifacts_gettr = run_lrp.use_artifact if config_lrp.use_wandb else api.artifact
    enc_artifact = artifacts_gettr(config_emb['enc_artifact'], type='learner')
    if print_flag: print (enc_artifact.name)
    ## TODO: This only works when you run it two timeS! WTF?
    try:
        enc_learner = enc_artifact.to_obj()
    except:
        enc_learner = enc_artifact.to_obj()
    
    ## Restore artifact
    enc_logger = enc_artifact.logged_by()
    enc_artifact_train = artifacts_gettr(enc_logger.config['train_artifact'], type='dataset')
    #cfg_.show_attrdict(enc_logger.config)
    if enc_logger.config['valid_artifact'] is not None:
        enc_artifact_valid = artifacts_gettr(enc_logger.config['valid_artifact'], type='dataset')
        if print_flag: print("enc_artifact_valid:", enc_artifact_valid.name)
    if print_flag: print("enc_artifact_train: ", enc_artifact_train.name)
    
    if config_dr['dr_artifact'] is not None:
        print("Is not none")
        dr_artifact = artifacts_gettr(config_dr['enc_artifact'])
    else:
        dr_artifact = enc_artifact_train
    if print_flag: print("DR artifact train: ", dr_artifact.name)
    if print_flag: print("--> DR artifact name", dr_artifact.name)
    dr_artifact
    df = dr_artifact.to_df()
    if print_flag: print("--> DR After to df", df.shape)
    if print_flag: display(df.head())
    return df, dr_artifact, enc_artifact, enc_learner

# %% ../nbs/xai.ipynb 6
def umap_parameters(config_dr, config):
    umap_params_cpu = {
        'n_neighbors' : config_dr.n_neighbors,
        'min_dist' : config_dr.min_dist,
        'random_state': np.uint64(822569775), 
        'metric': config_dr.metric,
        #'a': 1.5769434601962196,
        #'b': 0.8950608779914887,
        #'metric_kwds': {'p': 2}, #No debería ser necesario, just in case
        #'output_metric': 'euclidean',
        'verbose': 4,
        #'n_epochs': 200
    }
    umap_params_gpu = {
        'n_neighbors' : config_dr.n_neighbors,
        'min_dist' : config_dr.min_dist,
        'random_state': np.uint64(1234), 
        'metric': config_dr.metric,
        'a': 1.5769434601962196,
        'b': 0.8950608779914887,
        'target_metric': 'euclidean',
        'target_n_neighbors': config_dr.n_neighbors,
        'verbose': 4, #6, #CUML_LEVEL_TRACE
        'n_epochs': 200*3*2,
        'init': 'random',
        'hash_input': True
    }
    if config.cpu_flag: 
        umap_params = umap_params_cpu
    else:
        umap_params = umap_params_gpu
    return umap_params

# %% ../nbs/xai.ipynb 7
def get_prjs(embs_no_nan, config_dr, config, print_flag = False):
    umap_params = umap_parameters(config_dr, config)
    prjs_pca = get_PCA_prjs(
        X    = embs_no_nan, 
        cpu  = False,  
        print_flag = print_flag, 
        **umap_params
    )
    if print_flag: 
        print(prjs_pca.shape)
    prjs_umap = get_UMAP_prjs(
        input_data = prjs_pca, 
        cpu =  config.cpu_flag, #config_dr.cpu, 
        print_flag = print_flag,         
        **umap_params
    )
    if print_flag: prjs_umap.shape
    return prjs_umap

# %% ../nbs/xai.ipynb 9
def plot_projections(prjs, umap_params, fig_size = (25,25)):
    "Plot 2D projections thorugh a connected scatter plot"
    df_prjs = pd.DataFrame(prjs, columns = ['x1', 'x2'])
    fig = plt.figure(figsize=(fig_size[0],fig_size[1]))
    ax = fig.add_subplot(111)
    ax.scatter(df_prjs['x1'], df_prjs['x2'], marker='o', facecolors='none', edgecolors='b', alpha=0.1)
    ax.plot(df_prjs['x1'], df_prjs['x2'], alpha=0.5, picker=1)
    plt.title('DR params -  n_neighbors:{:d} min_dist:{:f}'.format(
        umap_params['n_neighbors'],umap_params['min_dist']))
    return ax

# %% ../nbs/xai.ipynb 10
def plot_projections_clusters(prjs, clusters_labels, umap_params, fig_size = (25,25)):
    "Plot 2D projections thorugh a connected scatter plot"
    df_prjs = pd.DataFrame(prjs, columns = ['x1', 'x2'])
    df_prjs['cluster'] = clusters_labels
    
    fig = plt.figure(figsize=(fig_size[0],fig_size[1]))
    ax = fig.add_subplot(111)
    
    # Create a scatter plot for each cluster with different colors
    unique_labels = df_prjs['cluster'].unique()
    print(unique_labels)
    for label in unique_labels:
        cluster_data = df_prjs[df_prjs['cluster'] == label]
        ax.scatter(cluster_data['x1'], cluster_data['x2'], label=f'Cluster {label}')
        #ax.scatter(df_prjs['x1'], df_prjs['x2'], marker='o', facecolors='none', edgecolors='b', alpha=0.1)
    
    #ax.plot(df_prjs['x1'], df_prjs['x2'], alpha=0.5, picker=1)
    plt.title('DR params -  n_neighbors:{:d} min_dist:{:f}'.format(
        umap_params['n_neighbors'],umap_params['min_dist']))
    return ax

# %% ../nbs/xai.ipynb 11
def calculate_cluster_stats(data, labels):
    """Computes the media and the standard deviation for every cluster."""
    cluster_stats = {}
    for label in np.unique(labels):
        #members = data[labels == label]
        members = data
        mean = np.mean(members, axis = 0)
        std = np.std(members, axis = 0)
        cluster_stats[label] = (mean, std)
    return cluster_stats

# %% ../nbs/xai.ipynb 12
def anomaly_score(point, cluster_stats, label):
    """Computes an anomaly score for each point."""
    mean, std = cluster_stats[label]
    return np.linalg.norm((point - mean) / std)

# %% ../nbs/xai.ipynb 13
def detector(data, labels):
    """Anomaly detection function."""
    cluster_stats = calculate_cluster_stats(data, labels)
    scores = []
    for point, label in zip(data, labels):
        score = anomaly_score(point, cluster_stats, label)
        scores.append(score)
    return np.array(scores)

# %% ../nbs/xai.ipynb 15
def plot_anomaly_scores_distribution(anomaly_scores):
    "Plot the distribution of anomaly scores to check for normality"
    plt.figure(figsize=(10, 6))
    sns.histplot(anomaly_scores, kde=True, bins=30)
    plt.title("Distribución de Anomaly Scores")
    plt.xlabel("Anomaly Score")
    plt.ylabel("Frecuencia")
    plt.show()

# %% ../nbs/xai.ipynb 16
def plot_clusters_with_anomalies(prjs, clusters_labels, anomaly_scores, threshold, fig_size=(25, 25)):
    "Plot 2D projections of clusters and superimpose anomalies"
    df_prjs = pd.DataFrame(prjs, columns=['x1', 'x2'])
    df_prjs['cluster'] = clusters_labels
    df_prjs['anomaly'] = anomaly_scores > threshold

    fig = plt.figure(figsize=(fig_size[0], fig_size[1]))
    ax = fig.add_subplot(111)

    # Plot each cluster with different colors
    unique_labels = df_prjs['cluster'].unique()
    for label in unique_labels:
        cluster_data = df_prjs[df_prjs['cluster'] == label]
        ax.scatter(cluster_data['x1'], cluster_data['x2'], label=f'Cluster {label}', alpha=0.7)

    # Superimpose anomalies
    anomalies = df_prjs[df_prjs['anomaly']]
    ax.scatter(anomalies['x1'], anomalies['x2'], color='red', label='Anomalies', edgecolor='k', s=50)

    plt.title('Clusters and anomalies')
    plt.legend()
    plt.show()

def update_plot(threshold, prjs_umap, clusters_labels, anomaly_scores, fig_size):
    plot_clusters_with_anomalies(prjs_umap, clusters_labels, anomaly_scores, threshold, fig_size)

def plot_clusters_with_anomalies_interactive_plot(threshold, prjs_umap, clusters_labels, anomaly_scores, fig_size):
    threshold_slider = widgets.FloatSlider(value=threshold, min=0.001, max=3, step=0.001, description='Threshold')
    interactive_plot =  widgets.interactive(update_plot, threshold = threshold_slider, 
                              prjs_umap = widgets.fixed(prjs_umap), 
                              clusters_labels = widgets.fixed(clusters_labels),
                              anomaly_scores = widgets.fixed(anomaly_scores),
                              fig_size = widgets.fixed((25,25)))
    display(interactive_plot)
    

# %% ../nbs/xai.ipynb 18
import plotly.express as px
from datetime import timedelta

# %% ../nbs/xai.ipynb 19
def get_df_selected(df, selected_indices, w, stride = 1): #Cuidado con stride
    '''Links back the selected points to the original dataframe and returns the associated windows indices'''
    n_windows = len(selected_indices)
    window_ranges = [(id*stride, (id*stride)+w) for id in selected_indices]    
    #window_ranges = [(id*w, (id+1)*w+1) for id in selected_indices]    
    #window_ranges = [(id*stride, (id*stride)+w) for id in selected_indices]
    #print(window_ranges)
    valores_tramos = [df.iloc[inicio:fin+1] for inicio, fin in window_ranges]
    df_selected = pd.concat(valores_tramos, ignore_index=False)
    return window_ranges, n_windows, df_selected

# %% ../nbs/xai.ipynb 20
def shift_datetime(dt, seconds, sign, dateformat="%Y-%m-%d %H:%M:%S.%f", print_flag = False):
    """
    This function gets a datetime dt, a number of seconds, 
    a sign and moves the date such number of seconds to the future 
    if sign is '+' and to the past if sing is '-'.
    """
    if print_flag: print(dateformat)
    dateformat2= "%Y-%m-%d %H:%M:%S.%f"
    dateformat3 = "%Y-%m-%d"
    ok = False
    try: 
        if print_flag: print("dt ", dt, "seconds", seconds, "sign", sign)
        new_dt = datetime.strptime(dt, dateformat)
        if print_flag: print("ndt", new_dt)
        ok = True
    except ValueError as e:
        if print_flag: 
            print("Error: ", e)
        
    if (not ok):
        try:
            if print_flag: print("Parsing alternative dataformat", dt, "seconds", seconds, "sign", sign, dateformat2)
            new_dt = datetime.strptime(dt, dateformat3)
            if print_flag: print("2ndt", new_dt)            
        except ValueError as e:
            print("Error: ", e)
    if print_flag: print(new_dt)
    try:
            
        if new_dt.hour == 0 and new_dt.minute == 0 and new_dt.second == 0:
            if print_flag: "Aqui"
            new_dt = new_dt.replace(hour=0, minute=0, second=0, microsecond=0)
            if print_flag: print(new_dt)

        if print_flag: print("ndt", new_dt)
                
        if (sign == '+'):
            if print_flag: print("Aqui")
            new_dt = new_dt + timedelta(seconds = seconds)
            if print_flag: print(new_dt)
        else: 
            if print_flag: print(sign, type(dt))
            new_dt = new_dt - timedelta(seconds = seconds)
            if print_flag: print(new_dt)            
        if new_dt.hour == 0 and new_dt.minute == 0 and new_dt.second == 0:
            if print_flag: print("replacing")
            new_dt = new_dt.replace(hour=0, minute=0, second=0, microsecond=0)
        
        new_dt_str = new_dt.strftime(dateformat)
        if print_flag: print("new dt ", new_dt)
    except ValueError as e:
        if print_flag: print("Aqui3")
        shift_datetime(dt, 0, sign, dateformat = "%Y-%m-%d", print_flag = False)
        return str(e)
    return new_dt_str



# %% ../nbs/xai.ipynb 22
def get_anomalies(df, threshold, flag):
    df['anomaly'] = [ (score > threshold) and flag for score in df['anomaly_score']]
    
def get_anomaly_styles(df, threshold, anomaly_scores, flag = False, print_flag = False):
        if print_flag: print("Threshold: ", threshold)
        if print_flag: print("Flag", flag)
        if print_flag: print("df ~", df.shape)
        df['anomaly'] = [ (score > threshold) and flag for score in df['anomaly_score'] ]
        if print_flag: print(df)
        get_anomalies(df, threshold, flag)
        anomalies = df[df['anomaly']]
        if flag:
            df['anomaly'] = [ 
                (score > threshold) and flag 
                for score in anomaly_scores 
            ]
            symbols = [
                'x' if is_anomaly else 'circle' 
                for is_anomaly in df['anomaly']
            ]
            line_colors = [
                'black'
                if (is_anomaly and flag) else 'rgba(0,0,0,0)'
                for is_anomaly in df['anomaly']
            ]
        else:
            symbols = ['circle' for _ in df['x1']]
            line_colors = ['rgba(0,0,0,0)' for _ in df['x1']]
        if print_flag: print(anomalies)
        return symbols, line_colors
### Example of use
#prjs_df = pd.DataFrame(prjs_umap, columns = ['x1', 'x2'])
#prjs_df['anomaly_score'] = anomaly_scores
#s, l = get_anomaly_styles(prjs_df, 1, True)

# %% ../nbs/xai.ipynb 23
class InteractiveAnomalyPlot():
    def __init__(
        self, selected_indices = [], 
        threshold = 0.15, 
        anomaly_flag = False,
        path = "../imgs", w = 0
    ):
        self.selected_indices = selected_indices
        self.selected_indices_tmp = selected_indices
        self.threshold = threshold
        self.threshold_ = threshold
        self.anomaly_flag = anomaly_flag
        self.w = w
        self.name = f"w={self.w}"
        self.path = f"{path}{self.name}.png"
        self.interaction_enabled = True
    

    def plot_projections_clusters_interactive(
        self, prjs, cluster_labels, umap_params, anomaly_scores=[], fig_size=(7,7), print_flag = False
    ):
        self.selected_indices_tmp = self.selected_indices
        py.init_notebook_mode()

        prjs_df, cluster_colors = plot_initial_config(prjs, cluster_labels, anomaly_scores)
        legend_items = [widgets.HTML(f'<b>Cluster {cluster}:</b> <span style="color:{color};">■</span>')
                        for cluster, color in cluster_colors.items()]
        legend = widgets.VBox(legend_items)

        marker_colors = prjs_df['cluster'].map(cluster_colors)
    
        symbols, line_colors = get_anomaly_styles(prjs_df, self.threshold_, anomaly_scores, self.anomaly_flag, print_flag)
    
        fig = go.FigureWidget(
            [
                go.Scatter(
                    x=prjs_df['x1'], y=prjs_df['x2'], 
                    mode="markers", 
                    marker= {
                        'color': marker_colors,
                        'line': { 'color': line_colors, 'width': 1 },
                        'symbol': symbols
                    },
                    text = prjs_df.index
                )
            ]
        )

        line_trace = go.Scatter(
            x=prjs_df['x1'],  # Reemplaza 'x1' y 'x2' con los nombres de tus columnas de datos
            y=prjs_df['x2'],  # Reemplaza 'x1' y 'x2' con los nombres de tus columnas de datos
            mode="lines",  # Establece el modo en "lines"
            line=dict(color='rgba(128, 128, 128, 0.5)', width=1)#,
            #showlegend=False  # Puedes configurar si deseas mostrar esta línea en la leyenda
        )
    
        fig.add_trace(line_trace)

        sca = fig.data[0]
        
        fig.update_layout(
            dragmode='lasso',
            width=700, 
            height=500,
            title={
                'text': '<span style="font-weight:bold">DR params - n_neighbors:{:d} min_dist:{:f}</span>'.format(
                         umap_params['n_neighbors'], umap_params['min_dist']),
                'y':0.98,
                'x':0.5,
                'xanchor': 'center',
                'yanchor': 'top'
            },
            plot_bgcolor='white',
            paper_bgcolor='#f0f0f0',
            xaxis=dict(gridcolor='lightgray', zerolinecolor='black', title = 'x'), 
            yaxis=dict(gridcolor='lightgray', zerolinecolor='black', title = 'y'),
            margin=dict(l=10, r=20, t=30, b=10)
        
        
        )
    
        output_tmp = Output()
        output_button = Output()
        output_anomaly = Output()
        output_threshold = Output()
    
    
        def select_action(trace, points, selector):
            self.selected_indices_tmp = points.point_inds
            with output_tmp:
                output_tmp.clear_output(wait=True)
                if print_flag: print("Selected indices tmp:", self.selected_indices_tmp)
        
        def button_action(b):
            self.selected_indices = self.selected_indices_tmp 
            with output_button: 
                output_button.clear_output(wait = True)
                if print_flag: print("Selected indices:", self.selected_indices)

    
        def update_anomalies():           
            if print_flag: print("About to update anomalies")
                
            symbols, line_colors = get_anomaly_styles(prjs_df, self.threshold_, anomaly_scores, self.anomaly_flag, print_flag)

            if print_flag: print("Anomaly styles got")

            with fig.batch_update():
                fig.data[0].marker.symbol = symbols
                fig.data[0].marker.line.color = line_colors
            if print_flag: print("Anomalies updated")
            if print_flag: print("Threshold: ", self.threshold_)
            if print_flag: print("Scores: ", anomaly_scores)
        
              
        def anomaly_action(b):
            with output_anomaly:  # Cambia output_flag a output_anomaly
                output_anomaly.clear_output(wait=True)
                if print_fllag: print("Negate anomaly flag")
                self.anomaly_flag = not self.anomaly_flag
                if print_flag: print("Show anomalies:", self.anomaly_flag)
                update_anomalies()
                              
        sca.on_selection(select_action)
        layout = widgets.Layout(width='auto', height='40px')
        button = Button(
            description="Update selected_indices",
            style = {'button_color': 'lightblue'},
            display = 'flex',
            flex_row = 'column',
            align_items = 'stretch',
            layout = layout
        )
        anomaly_button = Button(
            description = "Show anomalies",
            style = {'button_color': 'lightgray'},
            display = 'flex',
            flex_row = 'column',
            align_items = 'stretch',
            layout = layout
        )
        
        button.on_click(button_action)
        anomaly_button.on_click(anomaly_action)
    
        ##### Reactivity buttons
        pause_button = Button(
            description = "Pause interactiveness",
            style = {'button_color': 'pink'},
            display = 'flex',
            flex_row = 'column',
            align_items = 'stretch',
            layout = layout
        )
        resume_button = Button(
            description = "Resume interactiveness",
            style = {'button_color': 'lightgreen'},
            display = 'flex',
            flex_row = 'column',
            align_items = 'stretch',
            layout = layout
        )

    
        threshold_slider = FloatSlider(
            value=self.threshold_,
            min=0.0,
            max=float(np.ceil(self.threshold+5)),
            step=0.0001,
            description='Anomaly threshold:',
            continuous_update=False
        )
    
        def pause_interaction(b):
            self.interaction_enabled = False
            fig.update_layout(dragmode='pan')
    
        def resume_interaction(b):
            self.interaction_enabled = True
            fig.update_layout(dragmode='lasso')

    
        def update_threshold(change):
            with output_threshold: 
                output_threshold.clear_output(wait = True)
                if print_flag: print("Update threshold")
                self.threshold_ = change.new
                if print_flag: print("Update anomalies threshold = ", self.threshold_)
                update_anomalies()
        

        pause_button.on_click(pause_interaction)
        resume_button.on_click(resume_interaction)
    
        threshold_slider.observe(update_threshold, 'value')
    
        #####
        space = HTML("&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;") 
    
        vbox = VBox((output_tmp, output_button, output_anomaly, output_threshold, fig))
        hbox = HBox((space, button, space, pause_button, space, resume_button, anomaly_button))
    
        # Centrar las dos cajas horizontalmente en el VBox

        box_layout = widgets.Layout(display='flex',
                    flex_flow='column',
                    align_items='center',
                    width='100%')

        if self.anomaly_flag:
            box = VBox((hbox,threshold_slider,vbox), layout = box_layout)
        else: 
            box = VBox((hbox,vbox), layout = box_layout)
        box.add_class("layout")
        plot_save(fig, self.w)
    
        display(box)


# %% ../nbs/xai.ipynb 24
def plot_save(fig, w):
    image_bytes = pio.to_image(fig, format='png')
    with open(f"../imgs/w={w}.png", 'wb') as f:
        f.write(image_bytes)
    

# %% ../nbs/xai.ipynb 25
def plot_initial_config(prjs, cluster_labels, anomaly_scores):
    prjs_df = pd.DataFrame(prjs, columns = ['x1', 'x2'])
    prjs_df['cluster'] = cluster_labels
    prjs_df['anomaly_score'] = anomaly_scores
    
    cluster_colors_df = pd.DataFrame({'cluster': cluster_labels}).drop_duplicates()
    cluster_colors_df['color'] = px.colors.qualitative.Set1[:len(cluster_colors_df)]
    cluster_colors = dict(zip(cluster_colors_df['cluster'], cluster_colors_df['color']))
    return prjs_df, cluster_colors

# %% ../nbs/xai.ipynb 26
def ts_plot_interactive(
    df, selected_indices, meaningful_features_subset_ids, w, stride = 1, print_flag = False
):
    window_ranges, n_windows, df_selected = get_df_selected(df, selected_indices, w, stride)

    if print_flag: print(n_windows, window_ranges)
    if print_flag: print(df_selected.index)
    
    df.index = df.index.astype(str)
    dateformat = '%Y-%m-%d %H:%M:%S'
    #df.index = pd.to_datetime(df.index)
    #df.index = df.index.strftime(dateformat)
    
    fig = go.FigureWidget()
    
    colors = [f'rgb({np.random.randint(0, 256)}, {np.random.randint(0, 256)}, {np.random.randint(0, 256)})' for _ in range(n_windows)]
    
    # Agregar cada serie al gráfico con sombreado si está en df_selected
    output_windows = Output()
    for feature_id in df.columns:
        feature_pos = df.columns.get_loc(feature_id)
        trace = go.Scatter(
            x=df.index,
            y=df[feature_id],
            mode='lines',
            name=feature_id,
            visible=feature_pos in meaningful_features_subset_ids,
            text=df.index
        )
        fig.add_trace(trace)
        
    # Aplicar sombreado a las ventanas dentro de df_selected
    for i, (start, end) in enumerate(window_ranges):
        
        fig.add_shape(
            type="rect",
            x0=df.index[start],
            x1=df.index[end],
            y0= df[feature_id].min(),
            y1= df[feature_id].max(),
            fillcolor=colors[i], #"LightSalmon",
            opacity=0.25,
            layer="below",
            line=dict(color=colors[i], width=1),
            name = f"w_{i}"
        )
        with output_windows:
            print("w[" + str( selected_indices[i] )+ "]="+str(df.index[start])+", "+str(df.index[end])+")")
    
    fig.update_layout(
        title='Time Series with time window plot',
        xaxis_title='Datetime',
        yaxis_title='Value',
        legend_title='Variables',
        margin=dict(l=10, r=10, t=30, b=10),
        xaxis=dict(
            tickformat=dateformat#,
            #grid_color = 'lightgray', zerolinecolor='black', title = 'x'
        ),
        #yaxis = dict(grid_color = 'lightgray', zerolinecolor='black', title = 'y'),
        #plot_color = 'white',
        paper_bgcolor='#f0f0f0'
    )

    # Función para manejar el evento del botón
    def toggle_trace(button):
        idx = button.description
        trace = fig.data[df.columns.get_loc(idx)]
        trace.visible = not trace.visible

    # Crear un botón para cada variable
    buttons = [
        Button(
            description=str(feature_id),
            button_style='success' if df.columns.get_loc(feature_id) in meaningful_features_subset_ids else '') 
        for feature_id in df.columns
    ]

    for button in buttons:
        button.on_click(toggle_trace)

    output_move = Output()
    output_delta_x = Output()
    output_delta_y = Output()
    

    delta_x = 10   
    delta_y = 0.1
    
    def move_left(button):
        with output_move:
            output_move.clear_output(wait=True)
            start_date, end_date = fig.layout.xaxis.range
            new_start_date = shift_datetime(start_date, delta_x, '-', dateformat) 
            new_end_date = shift_datetime(end_date, delta_x, '-', dateformat) 
            with fig.batch_update():
                fig.layout.xaxis.range = [new_start_date, new_end_date]

    def move_right(button):
        output_move.clear_output(wait=True)
        with output_move:
            start_date, end_date = fig.layout.xaxis.range
            new_start_date = shift_datetime(start_date, delta_x, '+', dateformat) 
            new_end_date = shift_datetime(end_date, delta_x, '+', dateformat) 
            with fig.batch_update():
                fig.layout.xaxis.range = [new_start_date, new_end_date]
        
    def move_down(button):
        with output_move:
            output_move.clear_output(wait=True)
            start_y, end_y = fig.layout.yaxis.range
            with fig.batch_update():
                fig.layout.yaxis.range = [start_y-delta_y, end_y-delta_y]

    def move_up(button):
        with output_move:
            output_move.clear_output(wait=True)
            start_y, end_y = fig.layout.yaxis.range
            with fig.batch_update():
                fig.layout.yaxis.range = [start_y+delta_y, end_y+delta_y]

    def delta_x_bigger():
        nonlocal delta_x, delta_y
        with output_delta_x: 
            output_delta_x.clear_output(wait = True)
            print("Delta before", delta_x)
            delta_x = delta_x*10
            #print("Bigger delta_x")
            print("delta_x:", delta_x)

    def delta_y_bigger():
        nonlocal delta_x, delta_y
        with output_delta_y: 
            output_delta_y.clear_output(wait = True)
            print("Delta before", delta_y)
            delta_y = delta_y * 10
            print("delta_y:", delta_y)

    def delta_x_lower():
        nonlocal delta_x, delta_y
        with output_delta_x:
            output_delta_x.clear_output(wait = True)
            print("Delta before", delta_x)
            delta_x /= 10
            print("delta_x:", delta_x)

    def delta_y_lower():
        nonlocal delta_x, delta_y
        with output_delta_y: 
            output_delta_y.clear_output(wait = True)
            print("Delta before", delta_y)
            delta_y = delta_y * 10
            print("delta_y:", delta_y)
    
    button_left = Button(description="←")
    button_right = Button(description="→")
    button_up = Button(description="↑")
    button_down = Button(description="↓")
    
    button_step_x_up = Button(description="dx ↑")
    button_step_x_down = Button(description="dx ↓")
    button_step_y_up = Button(description="dy↑")
    button_step_y_down = Button(description="dy↓")


    # TODO: Arreglar que se pueda modificar el paso con el que se avanza. No se ve el output y no se modifica el valor
    button_step_x_up.on_click(delta_x_bigger)
    button_step_x_down.on_click(delta_x_lower)
    button_step_y_up.on_click(delta_y_bigger)
    button_step_y_down.on_click(delta_y_lower)
    
    
    steps_x = VBox([button_step_x_up, button_step_x_down])
    steps_y = VBox([button_step_y_up, button_step_y_down])


    button_left.on_click(move_left)
    button_right.on_click(move_right)
    button_up.on_click(move_up)
    button_down.on_click(move_down)
    
    arrow_buttons = HBox([button_left, button_right, button_up, button_down, steps_x, steps_y])
    
    # Organizar los botones en un layout horizontal
    hbox_layout = widgets.Layout(display='flex', flex_flow='row wrap', align_items='flex-start')
    
    hbox = HBox(buttons, layout=hbox_layout)

    # Mostrar el gráfico y los botones
    box_layout = widgets.Layout(display='flex',
                flex_flow='column',
                align_items='center',
                width='100%')

    box = VBox([hbox, arrow_buttons, output_move, output_delta_x, output_delta_y, fig, output_windows], layout=box_layout)
    
    display(box)

