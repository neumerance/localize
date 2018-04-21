FactoryGirl.define do
  factory :text_resource, class: TextResource do
    name { Faker::Name.name }
    description { Faker::Lorem.word }
    language_id 1
  end
end
