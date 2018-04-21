FactoryGirl.define do
  factory :translation_memory do
    association(:client, factory: :client)
    association(:language, factory: :language)
    signature { Faker::Crypto.md5 }
    content { Faker::Lorem.sentence }
  end
end
