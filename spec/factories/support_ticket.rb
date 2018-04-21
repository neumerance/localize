FactoryGirl.define do
  factory :support_ticket, class: SupportTicket do
    association :normal_user, factory: :user
    association :supporter, factory: :supporter
    association :support_department, factory: :support_department
    subject { Faker::Lorem.words(4).join(' ') }
    status 1
    message { Faker::Lorem.words(14).join(' ') }

    before(:create) do |sp|
      sp.messages << FactoryGirl.build(:message, owner: sp)
    end
  end
end
