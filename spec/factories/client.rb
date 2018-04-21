FactoryGirl.define do
  factory :client, class: Client do
    sequence(:nickname) { |n| "#{Faker::Internet.unique.user_name}#{n}" }
    sequence(:email) { |n| Faker::Internet.unique.email.gsub('@', "#{n}@") }
    password '123456'
    fname { Faker::Name.first_name }
    lname { Faker::Name.last_name }
    userstatus 2
    type 'Client'
    api_key { Faker::Crypto.md5 }

    trait :with_money_account do
      association :money_account, factory: :user_account, strategy: :create
    end
  end
end
