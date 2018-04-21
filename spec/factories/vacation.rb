FactoryGirl.define do
  factory :vacation, class: Vacation do
    user
    beginning { Time.zone.now + 1.day }
    ending { Time.zone.now + 5.days }
  end
end
