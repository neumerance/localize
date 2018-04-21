require 'rubygems'
require 'rest-client'

if ARGV[0].nil?
  puts 'Usage: ./script/runner ./script/create_test_snapshots.rb <website_id> <sandbox.icanlocalize.com>'
  exit
end

website_id = ARGV.shift
icl_host = ARGV.shift || 'sandbox.icanlocalize.com'

%w(Spanish French German).each do |to_language|
  wtt ||= 0
  tw ||= 0

  accesskey = Website.find(website_id).accesskey
  from_language = 'English'
  date = Date.today - 90.days

  90.times do
    puts RestClient.post "#{icl_host}/translation_snapshots/create_by_cms",         website_id: website_id,
                                                                                    accesskey: accesskey,
                                                                                    date: date,
                                                                                    to_language_name: to_language,
                                                                                    from_language_name: from_language,
                                                                                    words_to_translate: wtt,
                                                                                    translated_words: tw
    wtt += 10000 if rand < 0.08
    tw += 400 + rand(800)
    tw = wtt if tw > wtt
    date += 1.day
  end
end
