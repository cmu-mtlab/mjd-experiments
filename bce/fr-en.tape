global {

  ducttape_output=/usr0/home/mdenkows/bce/fr-en
  
  train_data_src=/usr0/home/mdenkows/bce/data/news-commentary-v10.fr-en.fr
  train_data_tgt=/usr0/home/mdenkows/bce/data/news-commentary-v10.fr-en.en

  mono_data_src=/usr0/home/mdenkows/bce/data/news.2012.fr.shuffled.uniq
  mono_data_tgt=/usr0/home/mdenkows/bce/data/news.2012.en.shuffled.uniq
  
  dev_data_src=/usr0/home/mdenkows/bce/data/dev/newstest2012.fr
  dev_data_tgt=/usr0/home/mdenkows/bce/data/dev/newstest2012.en

  test_data_src=/usr0/home/mdenkows/bce/data/dev/newstest2013.fr
  test_data_tgt=/usr0/home/mdenkows/bce/data/dev/newstest2013.en

  src_lang=es
  tgt_lang=en

  lm_order=4

  num_clusters=(NumClusters: 50 100 200)

  sparse_surface_context=(SparseSurfaceContext: 0 1)
  sparse_cluster_context=(SparseClusterContext: 0 1)
}

plan main {
  # Baseline
  reach eval via (Trial: 1)
  # BC Phrase table
  reach eval via (Trial: 1) * (ClusterFeatures: yes) * (NumClusters: 200)
  # BC RO
  reach eval via (Trial: 1) * (ClusterFeatures: yes) * (NumClusters: 200) * (ClusterRO: yes) * (ClusterIn: yes) * (ClusterOut: yes)
  # Surface features
  # reach eval via (Trial: 1) * (SparseSurface: yes)
  # Cluster features
  # reach eval via (Trial: 1) * (SparseCluster: yes) * (ClusterData: bitext) * (NumClusters: 50)
  # Both
  # reach eval via (Trial: 1) * (SparseSurface: yes) * (SparseCluster: yes) * (SparseClusterContext: 0) * (ClusterData: bitext) * (NumClusters: 50 100 200)
  # reach eval via (Trial: 1) * (SparseSurface: yes) * (SparseCluster: yes) * (SparseClusterContext: 0) * (ClusterData: mono) * (NumClusters: 50 100 200)
  # Context
  # reach eval via (Trial: 1) * (SparseSurface: yes) * (SparseSurfaceContext: 1)
  # reach eval via (Trial: 1) * (SparseSurface: yes) * (SparseCluster: yes) * (SparseClusterContext: 1) * (ClusterData: mono) * (NumClusters: 50 100 200)
}
