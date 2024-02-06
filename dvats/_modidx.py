# Autogenerated by nbdev

d = { 'settings': { 'branch': 'master',
                'doc_baseurl': '/dvats/',
                'doc_host': 'https://vrodriguezf.github.io',
                'git_url': 'https://github.com/vrodriguezf/deepvats',
                'lib_path': 'dvats'},
  'syms': { 'dvats.all': {},
            'dvats.dr': { 'dvats.dr.check_compatibility': ('dr.html#check_compatibility', 'dvats/dr.py'),
                          'dvats.dr.cluster_score': ('dr.html#cluster_score', 'dvats/dr.py'),
                          'dvats.dr.color_for_percentage': ('dr.html#color_for_percentage', 'dvats/dr.py'),
                          'dvats.dr.create_bar': ('dr.html#create_bar', 'dvats/dr.py'),
                          'dvats.dr.get_PCA_prjs': ('dr.html#get_pca_prjs', 'dvats/dr.py'),
                          'dvats.dr.get_TSNE_prjs': ('dr.html#get_tsne_prjs', 'dvats/dr.py'),
                          'dvats.dr.get_UMAP_prjs': ('dr.html#get_umap_prjs', 'dvats/dr.py'),
                          'dvats.dr.get_gpu_memory': ('dr.html#get_gpu_memory', 'dvats/dr.py'),
                          'dvats.dr.gpu_memory_status': ('dr.html#gpu_memory_status', 'dvats/dr.py')},
            'dvats.encoder': { 'dvats.encoder.DCAE_torch': ('encoder.html#dcae_torch', 'dvats/encoder.py'),
                               'dvats.encoder.DCAE_torch.__init__': ('encoder.html#__init__', 'dvats/encoder.py'),
                               'dvats.encoder.DCAE_torch.forward': ('encoder.html#forward', 'dvats/encoder.py'),
                               'dvats.encoder.color_for_percentage': ('encoder.html#color_for_percentage', 'dvats/encoder.py'),
                               'dvats.encoder.create_bar': ('encoder.html#create_bar', 'dvats/encoder.py'),
                               'dvats.encoder.get_enc_embs': ('encoder.html#get_enc_embs', 'dvats/encoder.py'),
                               'dvats.encoder.get_enc_embs_set_stride_set_batch_size': ( 'encoder.html#get_enc_embs_set_stride_set_batch_size',
                                                                                         'dvats/encoder.py'),
                               'dvats.encoder.get_gpu_memory_': ('encoder.html#get_gpu_memory_', 'dvats/encoder.py'),
                               'dvats.encoder.gpu_memory_status_': ('encoder.html#gpu_memory_status_', 'dvats/encoder.py')},
            'dvats.imports': {},
            'dvats.load': { 'dvats.load.TSArtifact': ('load.html#tsartifact', 'dvats/load.py'),
                            'dvats.load.TSArtifact.__init__': ('load.html#__init__', 'dvats/load.py'),
                            'dvats.load.TSArtifact.from_daily_csv_files': ('load.html#from_daily_csv_files', 'dvats/load.py'),
                            'dvats.load.TSArtifact.from_df': ('load.html#from_df', 'dvats/load.py'),
                            'dvats.load.infer_or_inject_freq': ('load.html#infer_or_inject_freq', 'dvats/load.py'),
                            'dvats.load.wandb.apis.public.Artifact.to_df': ('load.html#wandb.apis.public.artifact.to_df', 'dvats/load.py'),
                            'dvats.load.wandb.apis.public.Artifact.to_tsartifact': ( 'load.html#wandb.apis.public.artifact.to_tsartifact',
                                                                                     'dvats/load.py')},
            'dvats.utils': { 'dvats.utils.Learner.export_and_get': ('utils.html#learner.export_and_get', 'dvats/utils.py'),
                             'dvats.utils.PrintLayer': ('utils.html#printlayer', 'dvats/utils.py'),
                             'dvats.utils.PrintLayer.__init__': ('utils.html#__init__', 'dvats/utils.py'),
                             'dvats.utils.PrintLayer.forward': ('utils.html#forward', 'dvats/utils.py'),
                             'dvats.utils.ReferenceArtifact': ('utils.html#referenceartifact', 'dvats/utils.py'),
                             'dvats.utils.ReferenceArtifact.__init__': ('utils.html#__init__', 'dvats/utils.py'),
                             'dvats.utils.exec_with_and_feather_k_output': ('utils.html#exec_with_and_feather_k_output', 'dvats/utils.py'),
                             'dvats.utils.exec_with_feather': ('utils.html#exec_with_feather', 'dvats/utils.py'),
                             'dvats.utils.exec_with_feather_k_output': ('utils.html#exec_with_feather_k_output', 'dvats/utils.py'),
                             'dvats.utils.generate_TS_df': ('utils.html#generate_ts_df', 'dvats/utils.py'),
                             'dvats.utils.get_pickle_artifact': ('utils.html#get_pickle_artifact', 'dvats/utils.py'),
                             'dvats.utils.get_wandb_artifacts': ('utils.html#get_wandb_artifacts', 'dvats/utils.py'),
                             'dvats.utils.learner_module_leaves': ('utils.html#learner_module_leaves', 'dvats/utils.py'),
                             'dvats.utils.learner_module_leaves_subtables': ( 'utils.html#learner_module_leaves_subtables',
                                                                              'dvats/utils.py'),
                             'dvats.utils.normalize_columns': ('utils.html#normalize_columns', 'dvats/utils.py'),
                             'dvats.utils.py_function': ('utils.html#py_function', 'dvats/utils.py'),
                             'dvats.utils.remove_constant_columns': ('utils.html#remove_constant_columns', 'dvats/utils.py'),
                             'dvats.utils.wandb.apis.public.Artifact.to_obj': ( 'utils.html#wandb.apis.public.artifact.to_obj',
                                                                                'dvats/utils.py')},
            'dvats.visualization': { 'dvats.visualization.plot_TS': ('visualization.html#plot_ts', 'dvats/visualization.py'),
                                     'dvats.visualization.plot_mask': ('visualization.html#plot_mask', 'dvats/visualization.py'),
                                     'dvats.visualization.plot_validation_ts_ae': ( 'visualization.html#plot_validation_ts_ae',
                                                                                    'dvats/visualization.py')},
            'dvats.xai': { 'dvats.xai.InteractiveAnomalyPlot': ('xai.html#interactiveanomalyplot', 'dvats/xai.py'),
                           'dvats.xai.InteractiveAnomalyPlot.__init__': ('xai.html#__init__', 'dvats/xai.py'),
                           'dvats.xai.InteractiveAnomalyPlot.plot_projections_clusters_interactive': ( 'xai.html#plot_projections_clusters_interactive',
                                                                                                       'dvats/xai.py'),
                           'dvats.xai.anomaly_score': ('xai.html#anomaly_score', 'dvats/xai.py'),
                           'dvats.xai.calculate_cluster_stats': ('xai.html#calculate_cluster_stats', 'dvats/xai.py'),
                           'dvats.xai.detector': ('xai.html#detector', 'dvats/xai.py'),
                           'dvats.xai.get_anomalies': ('xai.html#get_anomalies', 'dvats/xai.py'),
                           'dvats.xai.get_anomaly_styles': ('xai.html#get_anomaly_styles', 'dvats/xai.py'),
                           'dvats.xai.get_dataset': ('xai.html#get_dataset', 'dvats/xai.py'),
                           'dvats.xai.get_prjs': ('xai.html#get_prjs', 'dvats/xai.py'),
                           'dvats.xai.plot_anomaly_scores_distribution': ('xai.html#plot_anomaly_scores_distribution', 'dvats/xai.py'),
                           'dvats.xai.plot_clusters_with_anomalies': ('xai.html#plot_clusters_with_anomalies', 'dvats/xai.py'),
                           'dvats.xai.plot_clusters_with_anomalies_interactive_plot': ( 'xai.html#plot_clusters_with_anomalies_interactive_plot',
                                                                                        'dvats/xai.py'),
                           'dvats.xai.plot_initial_config': ('xai.html#plot_initial_config', 'dvats/xai.py'),
                           'dvats.xai.plot_projections': ('xai.html#plot_projections', 'dvats/xai.py'),
                           'dvats.xai.plot_projections_clusters': ('xai.html#plot_projections_clusters', 'dvats/xai.py'),
                           'dvats.xai.plot_save': ('xai.html#plot_save', 'dvats/xai.py'),
                           'dvats.xai.umap_parameters': ('xai.html#umap_parameters', 'dvats/xai.py'),
                           'dvats.xai.update_plot': ('xai.html#update_plot', 'dvats/xai.py')}}}