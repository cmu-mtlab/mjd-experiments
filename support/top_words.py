#!/usr/bin/env python

import collections
import sys

def main(argv):

    if len(argv[1:]) != 1:
        sys.stderr.write('Output top N words in corpus\n')
        sys.stderr.write('usage: {} N <in-corpus >out-words\n'.format(argv[0]))
        sys.exit(2)

    N = int(argv[1])
    wc = collections.Counter()

    for line in sys.stdin:
        for word in line.split():
            wc[word] += 1

    for (w, _) in wc.most_common(N):
        sys.stdout.write('{}\n'.format(w))

if __name__ == '__main__':
    main(sys.argv)
