FactoryGirl.define do
  factory :destination, class: Destination do
    url { Faker::Internet.url }
    language_id 1
    name { Faker::Superhero.name }
  end
end
