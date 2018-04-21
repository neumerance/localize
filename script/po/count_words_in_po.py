#!/usr/bin/env python

import string, sys, os

if len(sys.argv) < 2:
    print "usage: %s POfile"%os.path.basename(sys.argv[0])
    sys.exit()
fname = sys.argv[1]

f = open(fname,'r')
lines = f.readlines()
f.close()

sentences = 0
words = 0
last_found_source = None
last_found_translation = None
for line in lines:
    if line.startswith('msgid'):
        last_found_source = line[len('msgid')+2:-2]
    if line.startswith('msgstr'):
        last_found_translation = line[len('msgstr')+2:-2]
        if last_found_source:
            if (last_found_translation == '') or (last_found_translation==last_found_source):
                wc = len(string.split(last_found_source))
                words += wc
                sentences += 1
                last_found_source = None
                last_found_translation = None

print "Found %d new words in %d lines"%(words, sentences)
