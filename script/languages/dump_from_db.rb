f = File.open('icanlocalize_db_entries.po', 'wb')
fs = File.open(Rails.root + '/app/controllers/translations_stuff.rb', 'wb')
fs.write("class TranslationsStuffController < ApplicationController\ndef index\n")

strs = []

Language.all.each do |language|
  f.write("# Name of language\n")
  f.write("msgid \"%s\"\nmsgstr \"\"\n\n" % language.name)
  strs << language.name
end

Category.all.each do |category|
  f.write("# Name of category for project\n")
  f.write("msgid \"%s\"\nmsgstr \"\"\n\n" % category.name)
  strs << category.name
end

Country.all.each do |country|
  f.write("# Name of country\n")
  f.write("msgid \"%s\"\nmsgstr \"\"\n\n" % country.name)
  strs << country.name
end

fs.write("things = [%s]\n" % (strs.collect { |s| '_("%s")' % s }).join(', '))
fs.write("end\nend\n")

f.close
fs.close
