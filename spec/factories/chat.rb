FactoryGirl.define do
  factory :chat, class: Chat do
    association(:translator, factory: :translator)
  end
end
