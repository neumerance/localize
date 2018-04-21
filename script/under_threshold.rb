require 'rubygems'
require 'rest-client'

if ARGV[0].nil?
  puts 'Usage: ./script/runner ./script/under_threshold.rb <website id>'
  return
end

id = ARGV[0]
website = Website.find(id)

# Set alert
profile = website.translation_analytics_profile
profile.translation_under_estimated_time_alert = true
profile.translation_under_estimated_time_threshold = 80
profile.save!

# Create two snapshots without progress to trigger the alert
lp = profile.translation_analytics_language_pairs.first
puts RestClient.post 'sandbox.icanlocalize.com/translation_snapshots/create_by_cms', 	website_id: id,
                                                                                      accesskey: website.accesskey,
                                                                                      date: lp.translation_snapshots.last.date + 1.day,
                                                                                      to_language_name: lp.to_language.name,
                                                                                      from_language_name: lp.from_language.name,
                                                                                      words_to_translate: 10000,
                                                                                      translated_words: 9000

puts RestClient.post 'localhost:3000/translation_snapshots/create_by_cms', 	website_id: id,
                                                                            accesskey: website.accesskey,
                                                                            date: lp.translation_snapshots.last.date + 1.day,
                                                                            to_language_name: lp.to_language.name,
                                                                            from_language_name: lp.from_language.name,
                                                                            words_to_translate: 10000,
                                                                            translated_words: 9000
