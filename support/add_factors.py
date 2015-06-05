#!/usr/bin/env python

import collections
import sys

def main(argv):

    if len(argv[1:]) < 1:
        sys.stderr.write('Add factors to corpus\n')
        sys.stderr.write('usage: {} paths [-f] <in-corpus >out-factored\n'.format(argv[0]))
        sys.exit(2)

    clusters = dict(reversed(line.split()[:2]) for line in open(argv[1]))
    fo = len(argv[1:]) > 1 and argv[2] == '-f'

    for line in sys.stdin:
        sys.stdout.write('{}\n'.format(' '.join((clusters[word] if word in clusters else 'UNK') if fo else ('{}|{}'.format(word, clusters[word] if word in clusters else 'UNK')) for word in line.split())))

if __name__ == '__main__':
    main(sys.argv)
