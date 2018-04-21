require 'rubygems'
require 'awesome_print'
require 'pry'

if ARGV[0].nil?
  puts 'Usage: ./script/runner ./script/backup/restore_text_resource.rb <location>'
  exit
end

models = [TextResource, ResourceString, StringTranslation]
# ActiveRecord::Base.partial_updates = false
ActiveRecord::Base.lock_optimistically = false

location = ARGV.shift

puts "Restoring backup of Software Project from #{location}..."

backup = {
  text_resource: Marshal.load(File.read("#{location}/text_resource")),
  resource_strings: Marshal.load(File.read("#{location}/resource_strings")),
  string_translations: Marshal.load(File.read("#{location}/string_translations"))
}

# Maybe destroy?
text_resource = TextResource.new backup[:text_resource].attributes
text_resource.id = backup[:text_resource].id
text_resource.save

backup[:resource_strings].each do |rs|
  puts " -> ResourceString ##{rs.id}"
  ResourceString.where(id: rs.id).destroy_all
  resource_string = ResourceString.new rs.attributes
  resource_string.id = rs.id
  resource_string.save
end

backup[:string_translations].each do |group|
  group.each do |st|
    st.save
    string_translation = StringTranslation.new st.attributes
    string_translation.id = st.id
    string_translation.save
  end
end

puts 'Done: '
