$: << '../'
require 'project_language_adder'

t0 = Time.now
puts 'opening document'
la = ProjectLanguageAdder.new('OTG - english.xml')
puts "Took #{Time.now - t0} seconds"

t1 = Time.now
puts 'adding languages'
la.add_languages(%w(Spanish German))
puts "Took #{Time.now - t1} seconds"

t2 = Time.now
puts 'writing document'
la.write('OTG_enumerated.xml')
puts "Took #{Time.now - t2} seconds"

puts "Total: took #{Time.now - t0} seconds"
