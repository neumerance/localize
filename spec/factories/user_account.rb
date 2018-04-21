FactoryGirl.define do
  factory :user_account, class: UserAccount do
    association :currency, factory: :currency, strategy: :find_or_create
  end
end
