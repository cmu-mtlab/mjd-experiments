#!/usr/bin/env ducttape

# BCE: Brown Custers Everywhere

global {
  ducttape_experimental_imports=true
  ducttape_experimental_packages=true
  ducttape_experimental_submitters=true
}

import sdsc.tape

# Packages

package support :: .versioner=disk .path="/home/mdenkows/experiments/support/" {
  # scripts
}

package moses :: .versioner=disk .path="/home/mdenkows/bce/mosesdecoder/" {
  # ./bjam --with-boost=/home/mdenkows/prefix --static --with-tcmalloc --with-cmph=/home/mdenkows/prefix --with-mm -j 8
  # pre-built
}

# Two cdec packages because we want a new version of the tokenizer but a pre-compiled fast_align.
# At the time of writing, newer versions of cdec are problematic to compile in many computing environments.

package cdec_src :: .versioner=disk .path="/home/mdenkows/bce/cdec_src/" {
  # uncompiled source
}

package cdec_bin :: .versioner=disk .path="/home/mdenkows/rta/sw/cdec/" {
  # pre-compiled binary package
}

#package multeval :: .versioner=git .repo="https://github.com/jhclark/multeval.git" .ref="5469ed2b7834e70e67e509f4df2dd07055fcfd79" {
#  ./get_deps.sh
#  ant
#}

package multeval :: .versioner=disk .path="/home/mdenkows/bce/multeval-0.5.1" {
  # pre-compiled jar
}

package brown_cluster :: .versioner=git .repo="https://github.com/percyliang/brown-cluster.git" .ref="329dcd6fee4659e3bd554d29e898ff4dcc9b4240" {
  make -j 8
}

# Tasks

task tok_src : cdec_src
    < in=(DataSection: train=$train_data_src dev=$dev_data_src test=$test_data_src mono=$mono_data_src)
    > out=text.gz
    :: jobs=8
    :: .submitter=shell .walltime="24:00:00" .cpus=8 .vmem=16g {
  $cdec_src/corpus/tokenize-parallel.py $in $jobs $PWD |$cdec_src/corpus/moses-xml.pl escape |gzip >text.gz
}

task tok_tgt : cdec_src
    < in=(DataSection: train=$train_data_tgt dev=$dev_data_tgt test=$test_data_tgt mono=$mono_data_tgt)
    > out=text.gz
    :: jobs=8
    :: .submitter=shell .walltime="24:00:00" .cpus=8 .vmem=16g {
  $cdec_src/corpus/tokenize-parallel.py $in $jobs $PWD |$cdec_src/corpus/moses-xml.pl escape |gzip >text.gz
}

task tok_filter : cdec_src
    < in_src=$out@tok_src[DataSection:train]
    < in_tgt=$out@tok_tgt[DataSection:train]
    > out_src=src.gz
    > out_tgt=tgt.gz
    :: max_len=100
    :: .submitter=shell .walltime="24:00:00" .cpus=1 .vmem=2g {

  # cdec format
  paste <(zcat -f $in_src) <(zcat -f $in_tgt) |sed 's/\t/ ||| /g' >corpus

  $cdec_src/corpus/filter-length.pl -$max_len corpus >filtered

  # back to two files
  $cdec_src/corpus/cut-corpus.pl 1 <filtered |gzip >src.gz
  $cdec_src/corpus/cut-corpus.pl 2 <filtered |gzip >tgt.gz

  # cleanup
  rm corpus
  rm filtered
}

task align_dir : cdec_bin
    < src=$out_src@tok_filter
    < tgt=$out_tgt@tok_filter
    > align=align.gz
    > params
    > err
    :: reverse=(AlignDir: s2t="" t2s="-r")
    :: .submitter=shell .walltime="24:00:00" .cpus=8 .vmem=16g {
  # cdec format
  paste <(zcat -f $src) <(zcat -f $tgt) |sed 's/\t/ ||| /g' >corpus
  $cdec_bin/word-aligner/fast_align $reverse -i corpus -d -v -o -p $params 2>$err |gzip >align.gz
  # cleanup
  rm corpus
}

task align_sym : cdec_bin
    < align_s2t=$align@align_dir[AlignDir:s2t]
    < align_t2s=$align@align_dir[AlignDir:t2s]
    > align=align.gz
    :: heuristic=grow-diag-final-and
    :: .submitter=shell .walltime="24:00:00" .cpus=1 .vmem=2g {
  $cdec_bin/utils/atools -i <(zcat -f $align_s2t) -j <(zcat -f $align_t2s) -c $heuristic |gzip >align.gz
}

task lm_lmplz : moses
    < in=$out@tok_tgt[DataSection:mono]
    > arpa=arpa.gz
    :: order=$lm_order
    :: .submitter=shell .walltime="24:00:00" {
  zcat -f $in |$moses/bin/lmplz -o $order -T . |gzip >arpa.gz
}

task lm_binary : moses
    < arpa=@lm_lmplz
    > klm
    :: .submitter=shell .walltime="24:00:00" .cpus=8 .vmem=16g {
  $moses/bin/build_binary trie $arpa $klm
}

task cluster_learn : brown_cluster
    < in=(ClusterData:
        bitext=(DataSide: src=$out_src@tok_filter tgt=$out_tgt@tok_filter)
        mono=(DataSide: src=$out@tok_src[DataSection:mono] tgt=$out@tok_tgt[DataSection:mono]))
    > clusters
    :: num_clusters=@
    :: .submitter=shell .walltime="48:00:00" .cpus=8 .vmem=16g {
  $brown_cluster/wcluster --c $num_clusters --text <(zcat -f $in) --output_dir $clusters
}

task cluster_corpus : support
    < in=(DataSide:
        src=(DataSection:
            train=$out_src@tok_filter
            dev=$out@tok_src[DataSection:dev]
            test=$out@tok_src[DataSection:test]
            mono=$out@tok_src[DataSection:mono])
        tgt=(DataSection:
            train=$out_tgt@tok_filter
            dev=$out@tok_tgt[DataSection:dev]
            test=$out@tok_tgt[DataSection:test]
            mono=$out@tok_tgt[DataSection:mono]))
    < clusters=@cluster_learn
    > out=text.gz
    :: .submitter=shell .walltime="24:00:00" .cpus=1 .vmem=2g {
  zcat -f $in |$support/add_factors.py $clusters/paths |gzip >text.gz
}

task cluster_split : support
    < in=(DataSide: src=$out@cluster_corpus[DataSide:src] tgt=$out@cluster_corpus[DataSide:tgt])
    > out=text.gz
    :: factor=1
    :: .submitter=shell .walltime="24:00:00" .cpus=1 .vmem=2g {
  zcat -f $in |$support/split_factors.py $factor |gzip >text.gz
}

task model_lex : moses
    < src=(ModelType: surface=$out_src@tok_filter cluster=$out@cluster_split[DataSide:src])
    < tgt=(ModelType:
        surface=(ClusterOut: no=$out_tgt@tok_filter yes=$out@cluster_corpus[DataSide:tgt,DataSection:train])
        cluster=$out@cluster_split[DataSide:tgt])
    < align=@align_sym
    > lex_s2t
    > lex_t2s
    :: .submitter=shell .walltime="24:00:00" .cpus=8 .vmem=16g {
  $moses/scripts/training/get-lexical.perl $src $tgt $align lex
  mv lex.f2e $lex_s2t
  mv lex.e2f $lex_t2s
}

task model_extract : moses
    < src=(ModelType: surface=$out_src@tok_filter cluster=$out@cluster_split[DataSide:src])
    < tgt=(ModelType:
        surface=(ClusterOut: no=$out_tgt@tok_filter yes=$out@cluster_corpus[DataSide:tgt,DataSection:train])
        cluster=$out@cluster_split[DataSide:tgt])
    < align=@align_sym
    > phrases_sorted=phrases.sorted.gz
    > phrases_inv_sorted=phrases.inv.sorted.gz
    > phrases_o_sorted=phrases.o.sorted.gz
    :: num_jobs=8
    :: buffer=8G
    :: max_len=7
    :: .submitter=shell .walltime="24:00:00" {

  # extract-parallel.perl has issues with gzipped files
  zcat -f $src >src
  zcat -f $tgt >tgt
  zcat -f $align >align

  $moses/scripts/generic/extract-parallel.perl $num_jobs split "sort --parallel=$num_jobs -S$buffer" $moses/bin/extract tgt src align phrases $max_len orientation --GZOutput
  
  # Cleanup
  rm src
  rm tgt
  rm align
}

task model_score : moses
    < phrases_sorted=@model_extract
    < phrases_inv_sorted=@model_extract 
    < lex_s2t=@model_lex
    < lex_t2s=@model_lex
    > phrase_table=phrase_table.gz
    :: num_jobs=8
    :: num_threads=8
    :: buffer=8G
    :: .submitter=shell .walltime="24:00:00" {
  # Direct
  $moses/scripts/generic/score-parallel.perl $num_jobs "sort --parallel=$num_threads -S$buffer" $moses/bin/score $phrases_sorted $lex_s2t phrase_table.half.s2t.gz 0
  # Indirect
  $moses/scripts/generic/score-parallel.perl $num_jobs "sort --parallel=$num_threads -S$buffer" $moses/bin/score $phrases_inv_sorted $lex_t2s phrase_table.half.t2s.gz --Inverse 1
  # Consolidate
  $moses/bin/consolidate phrase_table.half.s2t.gz phrase_table.half.t2s.gz /dev/stdout |gzip >phrase_table.gz
}
 
task model_reordering : moses
    < phrases_o_sorted=@model_extract
    > reordering_table=reordering_table.gz
    :: smoothing=0.5
    :: type=wbe
    :: orientation=msd
    :: specification=wbe-msd-bidirectional-fe
    :: .submitter=shell .walltime="24:00:00" .cpus=4 .vmem=8g {
  $moses/bin/lexical-reordering-score $phrases_o_sorted $smoothing ro_ --model "$type $orientation $specification"
  mv ro_$specification.gz reordering_table.gz
}

task model_add_cluster_features : support
    < src_clusters=$clusters@cluster_learn[DataSide:src]
    < tgt_clusters=$clusters@cluster_learn[DataSide:tgt]
    < cluster_pt=$phrase_table@model_score[ModelType:cluster]
    < surface_pt=$phrase_table@model_score[ModelType:surface]
    > phrase_table=phrase_table.gz
    :: .submitter=shell .walltime="48:00:00" {
  zcat $surface_pt |scala $support/ClusterHelper/src/PTHelper.scala add $src_clusters/paths $tgt_clusters/paths |LC_ALL=C sort -T. -S8G --parallel=8 |gzip >surface-aug.gz
  scala $support/ClusterHelper/src/PTHelper.scala merge <(zcat surface-aug.gz) <(zcat $cluster_pt) |gzip >merged-aug.gz
  zcat merged-aug.gz |scala $support/ClusterHelper/src/PTHelper.scala rm |LC_ALL=C sort -T. -S8G --parallel=8 |gzip >phrase_table.gz
}

task model_bin_pt : moses
    < phrase_table=(ClusterFeatures: no=$phrase_table@model_score yes=$phrase_table@model_add_cluster_features)
    > bin_pt=phrase-table.minphr
    :: num_scores=(ClusterFeatures: no=4 yes=8)
    :: num_threads=32
    :: .submitter=shell .walltime="24:00:00" {
  $moses/bin/processPhraseTableMin -in $phrase_table -out phrase-table -nscores $num_scores -threads $num_threads
}

task model_bin_ro : moses
    < reordering_table=@model_reordering
    > bin_ro=reordering-table.minlexr
    :: num_threads=8
    :: .submitter=shell .walltime="24:00:00" {
  $moses/bin/processLexicalTableMin -in $reordering_table -out reordering-table -threads $num_threads
}

task model_top_words : support
    < corpus=(DataSide: src=$out_src@tok_filter tgt=$out_tgt@tok_filter)
    > top_words
    :: num_words=50
    :: .submitter=shell .walltime="24:00:00" .cpus=1 .vmem=2g { 
  zcat -f $corpus |$support/top_words.py $num_words >top_words
}

task moses_ini : support
    < bin_pt=@model_bin_pt
    < bin_ro=@model_bin_ro[ModelType:surface,ClusterOut:no]
    < bin_ro_cluster=(ClusterRO: no=/dev/null yes=$bin_ro@model_bin_ro[ModelType:cluster])
    < klm=@lm_binary
    < src_words=(SparseSurface: no=/dev/null yes=$top_words@model_top_words[DataSide:src])
    < tgt_words=(SparseSurface: no=/dev/null yes=$top_words@model_top_words[DataSide:tgt])
    > moses_init_ini=moses-init.ini
    :: lm_order=@
    :: pt_type="compact"
    :: cluster_pt=(ClusterFeatures: no yes)
    :: cluster_ro=(ClusterRO: no yes)
    :: sparse_surface=(SparseSurface: no yes)
    :: sparse_surface_context=@
    :: sparse_cluster=(SparseCluster: no yes)
    :: sparse_cluster_context=@
    :: .submitter=shell {

  cluster_pt_args=""
  if [[ $cluster_pt == "yes" ]]; then
    cluster_pt_args="--cluster-pt"
  fi

  cluster_ro_args=""
  if [[ $cluster_ro == "yes" ]]; then
    cluster_ro_args="--ro-cluster $bin_ro_cluster"
  fi

  sparse_surface_args=""
  if [[ $sparse_surface == "yes" ]]; then
    sparse_surface_args="--sparse-surface $src_words $tgt_words $sparse_surface_context"
  fi
  
  sparse_cluster_args=""
  if [[ $sparse_cluster == "yes" ]]; then
    sparse_cluster_args="--sparse-cluster $sparse_cluster_context"
  fi

  $support/moses_ini.py \
    --pt $bin_pt \
    --pt-type $pt_type \
    --ro $bin_ro \
    $cluster_ro_args \
    --lm $klm \
    --lm-order $lm_order \
    $cluster_pt_args \
    $sparse_surface_args \
    $sparse_cluster_args \
    >moses-init.ini
}

# Multiple optimizer runs via Trial instances
task tune_mira : moses support
    < src=(ClusterIn: no=$out@tok_src[DataSection:dev] yes=$out@cluster_corpus[DataSide:src,DataSection:dev])
    < tgt=$out@tok_tgt[DataSection:dev]
    < moses_init_ini=@moses_ini
    > moses_ini=moses.ini
    :: threads=8
    :: trial=(Trial: 1)
    :: .submitter=shell .walltime="168:00:00" {

  # Stage files (hard coded for SDSC, may be different or unnecessary in other environments)
  # SCRATCH=/scratch/$USER/$PBS_JOBID/
  # $support/stage_moses.py $moses_init_ini $SCRATCH >$SCRATCH/moses.ini 

  zcat -f $src >src
  zcat -f $tgt >refs

  # Run MIRA
  $moses/scripts/training/mert-moses.pl \
    --input $PWD/src \
    --refs $PWD/refs \
    --decoder $moses/bin/moses \
    --config $moses_init_ini \
    --working-dir $PWD \
    --batch-mira \
    --no-filter-phrase-table \
    --threads $threads \
    --decoder-flags=" -threads $threads"

  # mv moses.ini moses-staged.ini
  # $moses/scripts/ems/support/substitute-weights.perl $moses_init_ini $PWD/moses-staged.ini $PWD/moses.ini
}

task decode : moses support
    < src=(ClusterIn: no=$out@tok_src[DataSection:test] yes=$out@cluster_corpus[DataSide:src,DataSection:test])
    < moses_ini=@tune_mira
    > out
    :: threads=8
    :: .submitter=shell .walltime="24:00:00" {

  # Stage files (hard coded for SDSC, may be different or unnecessary in other environments)
  # SCRATCH=/scratch/$USER/$PBS_JOBID/
  # $support/stage_moses.py $moses_ini $SCRATCH >$SCRATCH/moses.ini
  
  zcat $src |$moses/bin/moses \
    -f $moses_ini \
    -threads $threads \
    >out
}

task eval : multeval
    < hyps=$out@decode[Trial:*]
    < refs=$out@tok_tgt[DataSection:test]
    > scores
    :: lang=$tgt_lang
    :: threads=4
    :: .submitter=shell .walltime="1:00:00" .cpus=4 .vmem=8g {
  ln -s $multeval/constants .
  $multeval/multeval.sh eval --meteor.language $lang --threads $threads --refs <(zcat -f $refs) --hyps-baseline $hyps >$scores
}
