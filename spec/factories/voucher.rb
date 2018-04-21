FactoryGirl.define do
  factory :voucher, class: Voucher do
    code { Faker::Color.color_name }
    active true
    amount { Faker::Number.decimal(2) }
    comments { Faker::Lorem.words(10).join(' ') }
  end
end
