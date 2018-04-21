FactoryGirl.define do
  factory :invoice, class: Invoice do
    kind 2
    payment_processor 1
    currency_id 1
    gross_amount 5.0
    net_amount 4.53
    txn '67F615412L727702M'
    status 2
    tax_amount 0.85
    tax_rate 17.0
    tax_country_id 129
    create_time { Time.now }
    modify_time { Time.now }
    association :user, factory: :client

    factory :invoice_with_vat do

      after(:create) do |invoice|
        invoice.update_attributes(source_id: invoice.user_id, source_type: 'User')
        FactoryGirl.create(:money_transaction_deposit, amount: invoice.gross_amount, owner_type: 'Invoice', owner_id: invoice.id)
        FactoryGirl.create(:money_transaction_vat, amount: invoice.tax_amount, owner_type: 'Invoice', owner_id: invoice.id)
        invoice.money_transactions.each do |mt|
          next unless mt.target_account.class.to_s == 'UserAccount'
          mt.target_account.update_attribute(:owner_id, invoice.user_id)
        end
      end

    end

  end
end
