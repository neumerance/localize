require 'rubygems'
require 'awesome_print'

if ARGV[0].nil?
  puts 'Usage: bundle exec ./script/runner ./script/backup/backup_text_resource.rb <text_resource_id> [<location>]'
  exit
end

id = ARGV.shift
OUTPUT_DIR = ARGV.shift || "/tmp/icl_text_resource_#{id}"

FileUtils.mkdir_p(OUTPUT_DIR)

text_resource = TextResource.find id

puts "Creating backup of Software Project: #{text_resource.id} - #{text_resource.name}..."

dump = {
  text_resource: Marshal.dump(text_resource),
  resource_strings: Marshal.dump(text_resource.resource_strings),
  string_translations: Marshal.dump(text_resource.resource_strings.map(&:string_translations))
}

dump.each do |d, data|
  File.open("#{OUTPUT_DIR}/#{d}", 'wb') { |f| f.write(data) }
end

# @ToDo backup also resource files

puts 'Done: ' + OUTPUT_DIR
