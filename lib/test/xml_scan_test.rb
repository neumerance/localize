$: << '../'
require 'xml_stream_listener'
require 'rexml/document'
require 'rexml/streamlistener'

f = open('OTG - english.xml', 'rb')
listener = XmlStreamListener.new
parser = REXML::Parsers::StreamParser.new(f, listener)
st = Time.now
parser.parse
f.close

puts "processed in #{Time.now - st} seconds"

# result = { "word_count" => listener.word_count }

listener.word_count.each do |lang, count_stat|
  count_stat.each { |stat, count| puts "#{lang}: #{count} '#{stat}' words" }
end

listener.sentence_count.each do |lang, count_stat|
  count_stat.each { |stat, count| puts "#{lang}: #{count} '#{stat}' sentences" }
end

listener.document_count.each do |lang, count_stat|
  count_stat.each { |stat, count| puts "#{lang}: #{count} '#{stat}' documents" }
end

# listener.support_files.each { |sf| puts "#{sf[0]}: #{sf[1]}" }
puts "#{listener.support_files.length} support files"
