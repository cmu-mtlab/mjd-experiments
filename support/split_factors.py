#!/usr/bin/env python

import sys

def main(argv):

    if len(argv[1:]) < 1:
        sys.stderr.write('Split factored corpus\n')
        sys.stderr.write('usage: {} N <in-corpus >out-single-factor\n'.format(argv[0]))
        sys.exit(2)

    N = int(argv[1])

    for line in sys.stdin:
        sys.stdout.write('{}\n'.format(' '.join(factors[N] for factors in (word.split('|') for word in line.split()))))

if __name__ == '__main__':
    main(sys.argv)
