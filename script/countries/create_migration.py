# -*- coding: UTF-8 -*-

import string

f = open('country_data.csv')
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
            code = w[2][1:-1]
            name = w[3][1:-1]
            #print language
            total_count += 1
            up_txt += ' country = Country.where("code = \'%s\'").first\n'%code
            up_txt += ' if not country\n'
            up_txt += '  Country.create(:code => "%s", :name => "%s", :major => %s)\n'%(code, name, major)
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

print "%d countries. %d major"%(total_count,major_count)

