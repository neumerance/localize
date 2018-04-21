FactoryGirl.define do
  factory :money_transaction, class: MoneyTransaction do
    amount 9.99
    fee_rate 0.0
    fee 0.0
    currency_id 1
    source_account_type 'ExternalAccount'
    source_account_id 7616
    target_account_type 'MoneyAccount'
    target_account_id 293174
    status 1
    chgtime { Time.now }
    lock_version 1
    affiliate_account_id nil

    factory :money_transaction_deposit do
      operation_code 4
      association :target_account, factory: :user_account
    end

    factory :money_transaction_vat do
      operation_code 30
      association :target_account, factory: :tax_account
    end
  end
end
