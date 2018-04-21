FactoryGirl.define do
  factory :external_account_paypal, class: ExternalAccount do
    owner_id 1
    external_account_type 1
    identifier { Faker::Internet.email }
  end
end
