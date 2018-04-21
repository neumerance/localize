FactoryGirl.define do
  # This does not move any money from the money_account.balance to the
  # money_account.hold_sum.
  factory :pending_money_transaction do
    association :owner, factory: :cms_request
    association :money_account
    amount 5.00
  end
end
