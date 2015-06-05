#!/usr/bin/env python

import glob
import os
import shutil
import sys

# Only stage files for these features
# (To avoid doing things like copying top_words for source and target on top of each other)
TO_STAGE = set(('KENLM', 'LexicalReordering', 'PhraseDictionaryCompact'))

def main(argv):

    if len(argv[1:]) != 2:
        sys.stderr.write('Stages files in moses.ini to directory and write new moses.ini\n')
        sys.stderr.write('Usage: {} moses.ini stage-dir >staged-moses.ini\n'.format(argv[0]))
        sys.exit(2)

    moses_ini = argv[1]
    stage_dir = os.path.abspath(argv[2])

    for line in open(moses_ini):
        fields = line.split()
        if fields and fields[0] in TO_STAGE:
            for i in range(len(fields)):
                # path=/some/path/to/file
                if fields[i].startswith('path='):
                    file = fields[i].split('=', 1)[1]
                    # Copy /some/path/to/file*
                    files = glob.glob('{}*'.format(file))
                    for f in files:
                        shutil.copy(f, stage_dir)
                    # Update path
                    fields[i] = 'path={}'.format(os.path.join(stage_dir, os.path.basename(file)))
        line = ' '.join(fields)
        sys.stdout.write('{}\n'.format(line))

if __name__ == '__main__':
    main(sys.argv)
