#!/usr/bin/env python

import collections
import gzip
import os
import sys

def main(argv):

    if len(argv[1:]) != 5:
        sys.stderr.write('Add cluster features to a phrase table\n')
        sys.stderr.write('Usage: {} src-paths tgt-paths cluster-pt.gz surface-pt.gz new-pt.gz\n'.format(argv[0]))
        sys.exit(2)

    src_paths = argv[1]
    tgt_paths = argv[2]
    cluster_pt = argv[3]
    surface_pt  = argv[4]
    new_pt  = argv[5]

    src_clusters = dict(reversed(line.split()[:2]) for line in open(src_paths))
    tgt_clusters = dict(reversed(line.split()[:2]) for line in open(tgt_paths))
    scores = collections.defaultdict(dict)

    i = 0
    for line in gzip.open(cluster_pt):
        fields = line.split(' ||| ')
        (src, tgt, score_str) = tuple(fields[0].split()), tuple(fields[1].split()), fields[2]
        scores[src][tgt] = score_str
        i += 1
        if i % 100000 == 0:
            sys.stderr.write('.')
    sys.stderr.write('\n')

    i = 0
    with gzip.open(new_pt, 'wb') as out:
        for line in gzip.open(surface_pt):
            fields = line.split(' ||| ')
            src = tuple(src_clusters[w] for w in fields[0].split())
            tgt = tuple(tgt_clusters[w] for w in fields[1].split())
            fields[2] = '{} {}'.format(fields[2], scores[src][tgt])
            line = ' ||| '.join(fields)
            # Splitting on ' ||| ' does not remove original newline
            out.write(line)
            i += 1
            if i % 100000 == 0:
                sys.stderr.write('.')
    sys.stderr.write('\n')

if __name__ == '__main__':
    main(sys.argv)
