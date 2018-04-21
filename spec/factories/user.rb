FactoryGirl.define do
  factory :user, class: User do
    sequence(:email) { |n| Faker::Internet.unique.email.gsub('@', "#{n}@") }
    sequence(:nickname) { |n| "#{Faker::Internet.unique.user_name}#{n}" }
    password '123456'
    fname { Faker::Superhero.power }
    lname { Faker::Superhero.power }
    userstatus 2
  end
end
