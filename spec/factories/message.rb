FactoryGirl.define do
  factory :message, class: Message do
    body { Faker::Lorem.words(20).join(' ') }
    chgtime { Time.now }
    is_new true
  end
end
