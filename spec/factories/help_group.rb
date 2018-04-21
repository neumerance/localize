FactoryGirl.define do
  factory :help_group, class: HelpGroup do
    order 0
    name { Faker::Educator.course }
  end
end
