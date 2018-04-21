# bundle exec ./script/runner ./script/text_resources/resource_strings_word_counter.rb
require 'rubygems'
require 'awesome_print'

strings = ResourceString.where(word_count: nil)
count = strings.count
ap "Processing #{count} strings"

times = []

strings.find_in_batches do |group|
  puts "Strings left: #{count}"

  times << Benchmark.realtime do
    group.each do |resource_string|
      resource_string.update_word_count
      resource_string.save
    end
  end

  count -= 1000

  average_per_batch = (times.sum / times.count).to_i
  batches_left = count / 1000

  estimated_time = Time.at(average_per_batch * batches_left).utc.strftime('%H:%M')
  puts "... done in #{times.last.to_i}s. Estimated time: #{estimated_time} hours"
end
