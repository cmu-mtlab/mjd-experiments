#!/usr/bin/env python

import argparse  
import os
import sys

MOSES_INI='''# mert-moses.pl will remove this line

[input-factors]
0
{in_factors}
[output-factors]
0

[mapping]
0 T 0

[distortion-limit]
6

[feature]
UnknownWordPenalty
WordPenalty
PhrasePenalty
Distortion
KENLM lazyken=1 name=LM factor=0 order={order} path={klm}
{ro_surface_line}{ro_cluster_line}
{pt_line}
{sparse_surface}{sparse_cluster}
[weight]
UnknownWordPenalty0= 1
WordPenalty0= 1
PhrasePenalty0= 1
Distortion0= 1
LM= 1
{ro_surface_weights}{ro_cluster_weights}
{pt_weights}
'''

def main(argv):

    parser = argparse.ArgumentParser()
    parser.add_argument('--cluster-pt', help='PT has cluster features', action='store_true')
    parser.add_argument('--lm', help='Binary language model', required=True)
    parser.add_argument('--lm-order', help='LM N-gram order', type=int, default=4)
    parser.add_argument('--pt', help='Binarized phrase table', required=True)
    parser.add_argument('--pt-type', help='(compact, mmsapt)', default='compact')
    parser.add_argument('--ro', help='Path to binarized reordering model bin_ro', required=True)
    parser.add_argument('--ro-cluster', help='Path to cluster binarized reordering model bin_ro')
    parser.add_argument('--sparse-cluster', help='Context length for sparse cluster features', metavar='CTX_LEN')
    parser.add_argument('--sparse-surface', help='Source and target words lists and source context length for sparse surface features', nargs=3, metavar=('SRC', 'TGT', 'CTX_LEN'))

    args = parser.parse_args(argv[1:])
    
    cluster_factor = any((args.ro_cluster, args.sparse_cluster))

    # Phrase table
    pt_line = ''
    pt_weights = ''
    if args.pt_type == 'compact':
        pt = os.path.abspath(args.pt)
        if pt.endswith('.minphr'):
            pt = pt[:-len('.minphr')]
        pt_line = 'PhraseDictionaryCompact name=TranslationModel table-limit=20 num-features={nf} path={pt} input-factor=0 output-factor=0{factors}'.format(nf=8 if args.cluster_pt else 4, pt=pt,factors=',1' if cluster_factor else '')
        pt_weights = 'TranslationModel= 1 1 1 1'
        if args.cluster_pt:
            pt_weights += ' 1 1 1 1'

    # Reordering
    ro = os.path.abspath(args.ro)
    if ro.endswith('.minlexr'):
        ro = ro[:-len('.minlexr')]
    ro_surface_line = 'LexicalReordering name=LexicalReordering0 num-features=6 type=msd-bidirectional-fe input-factor=0 output-factor=0 path={ro}'.format(ro=ro)
    ro_surface_weights = 'LexicalReordering0= 1 1 1 1 1 1'
    # Cluster
    ro_cluster_line = ''
    ro_cluster_weights = ''
    if args.ro_cluster:
        ro_cluster = os.path.abspath(args.ro_cluster)
        if ro_cluster.endswith('.minlexr'):
            ro_cluster = ro_cluster[:-len('.minlexr')]
        ro_cluster_line = '\nLexicalReordering name=LexicalReordering1 num-features=6 type=msd-bidirectional-fe input-factor=1 output-factor=1 path={ro_cluster}'.format(ro_cluster=ro_cluster)
        ro_cluster_weights = '\nLexicalReordering1= 1 1 1 1 1 1'

    # Language model
    lm = os.path.abspath(args.lm)

    # Sparse cluster features
    sparse_cluster = ''
    if args.sparse_cluster:
        sparse_cluster = '''SourceWordDeletionFeature factor=1
TargetWordInsertionFeature factor=1
WordTranslationFeature input-factor=1 output-factor=1 simple=1 source-context={ctx_len} target-context=0
'''.format(ctx_len=int(int(args.sparse_cluster)))
    
    # Sparse surface features
    sparse_surface = ''
    if args.sparse_surface:
        sparse_surface = '''SourceWordDeletionFeature factor=0 path={src}
TargetWordInsertionFeature factor=0 path={tgt}
WordTranslationFeature input-factor=0 output-factor=0 source-path={src} target-path={tgt} simple=1 source-context={ctx_len} target-context=0
'''.format(src=args.sparse_surface[0], tgt=args.sparse_surface[1], ctx_len=int(args.sparse_surface[2]))

    sys.stdout.write(MOSES_INI.format(
            in_factors='1\n' if cluster_factor else '',
            order=args.lm_order,
            klm=lm,
            ro_surface_line=ro_surface_line,
            ro_cluster_line=ro_cluster_line,
            pt_line=pt_line,
            sparse_cluster=sparse_cluster,
            sparse_surface=sparse_surface,
            pt_weights=pt_weights,
            ro_surface_weights=ro_surface_weights,
            ro_cluster_weights=ro_cluster_weights))

if __name__ == '__main__':
    main(sys.argv)
