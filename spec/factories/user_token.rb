FactoryGirl.define do
  factory :user_token, class: UserToken do
    token { Faker::Crypto.md5 }
    association :translator, factory: :translator
  end
end
