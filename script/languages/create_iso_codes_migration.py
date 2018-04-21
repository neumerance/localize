# -*- coding: UTF-8 -*-

import string

f = open('icl_language_codes.csv')
lines = f.readlines()
f.close()

up_txt = ''
major_count = 0
total_count = 0
for line in lines[1:]:
    w = string.split(string.replace(string.replace(line,'\r',''),'\n',''),',')
    name = w[1][1:-1]
    code = w[5][1:-1]

    total_count += 1

    up_txt += ' lang = Language.where("name = ?","%s").first\n'%name
    up_txt += ' if lang\n'
    up_txt += '   lang.update_attributes!(:iso=>"%s")\n'%code
    up_txt += ' end\n\n'

f = open('iso_codes_migration.rb','wt')
f.write('def self.up\n')
f.write(up_txt)
f.write('end\n\n\n')
f.write('def self.down\n')
f.write('end\n')
f.close()

print "%d languages."%total_count
