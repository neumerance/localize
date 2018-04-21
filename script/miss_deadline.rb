require 'rubygems'
require 'rest-client'

if ARGV[0].nil?
  puts 'Usage: ./script/runner ./script/miss_deadline.rb <site id>'
  return
end

id = ARGV[0]

website = Website.find(id)

# Set alert
profile = website.translation_analytics_profile
profile.missed_estimated_deadline_alert = true
profile.save!

# Set deadline
lp = profile.translation_analytics_language_pairs.first
lp.deadline = 1.day.ago
lp.save!

# Create snapshot and trigger alert
puts RestClient.post 'sandbox.icanlocalize.com/translation_snapshots/create_by_cms', 	website_id: id,
                                                                                      accesskey: website.accesskey,
                                                                                      date: Date.today,
                                                                                      to_language_name: lp.to_language.name,
                                                                                      from_language_name: lp.from_language.name,
                                                                                      words_to_translate: 10000,
                                                                                      translated_words: 9000
