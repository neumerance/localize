FactoryGirl.define do
  factory :managed_work, class: ManagedWork do
    active MANAGED_WORK_INACTIVE
    from_language_id 1
    to_language_id 2
  end
  trait :waiting_for_payment do
    translation_status MANAGED_WORK_WAITING_FOR_PAYMENT
  end
end
