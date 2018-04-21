FactoryGirl.define do
  factory :supporter, class: Supporter do
    sequence(:nickname) { |n| "#{Faker::Internet.unique.user_name}#{n}" }
    sequence(:email) { |n| Faker::Internet.unique.email.gsub('@', "#{n}@") }
    password '123456'
    fname { Faker::Name.first_name }
    lname { Faker::Name.last_name }
    userstatus 1
  end
end
