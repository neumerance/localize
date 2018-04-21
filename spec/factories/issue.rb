FactoryGirl.define do
  factory :issue, class: Issue do
    owner_id 306
    owner_type 'WebMessage'
    initiator_id 300
    target_id 294
    kind 4
    status 1
    title 'Text missing'
  end
end
