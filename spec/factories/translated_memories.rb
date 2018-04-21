FactoryGirl.define do
  factory :translated_memory do
    association(:client, factory: :client)
    content { Faker::Lorem.sentence }
  end
end
