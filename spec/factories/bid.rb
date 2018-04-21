FactoryGirl.define do
  factory :bid, class: Bid do
    association(:chat, factory: :chat)
    association(:revision_language, factory: :revision_language)
    amount 37.71
    currency_id 1
    accept_time nil
    expiration_time nil
    lock_version 1
    alert_status 0
  end
  trait :given do
    status BID_GIVEN
  end
  trait :accepted do
    status BID_ACCEPTED
  end
  trait :completed do
    status BID_COMPLETED
  end
  trait :waiting do
    status BID_WAITING_FOR_PAYMENT
  end
  trait :won do
    won true
  end
  trait :with_bid_account do
    after(:create) do |bid|
      FactoryGirl.create(:bid_account, owner_id: bid.id)
    end
  end
end
