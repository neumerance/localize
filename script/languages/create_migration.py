# -*- coding: UTF-8 -*-

import string

f = open('language_data.csv')
lines = f.readlines()
f.close()

up_txt = ''
major_count = 0
total_count = 0
for line in lines:
    if line[0] != '#':
        #print line
        w = string.split(line,',')
        if len(w) >= 7:
            major = w[0]
            language = w[6][1:-1]
            #print language
            total_count += 1
            up_txt += ' lang = Language.where("name = \'%s\'").first\n'%language
            up_txt += ' if not lang\n'
            up_txt += '  Language.create(:name => "%s", :major => %s)\n'%(language,major)
            up_txt += ' else\n'
            up_txt += '  lang.major = %s\n'%major
            up_txt += '  lang.save!\n'
            up_txt += ' end\n\n'
            if w[0] == '1':
                major_count += 1
f = open('migration.rb','wt')
f.write('def self.up\n')
f.write(up_txt)
f.write('end\n\n\n')
f.write('def self.down\n')
f.write('end\n')
f.close()

print "%d languages. %d major"%(total_count,major_count)

