FactoryGirl.define do
  factory :help_topic, class: HelpTopic do
    url { Faker::Internet.url }
    title { Faker::Lorem.words(5).join(' ') }
    summary { Faker::Lorem.words(15).join(' ') }
    display true
  end
end
