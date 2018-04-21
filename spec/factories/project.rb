FactoryGirl.define do
  factory :project, class: Project do
    name { Faker::Crypto.md5 }
    association :client, factory: :client
    creation_time { Time.now }
    private_key { Faker::Number.number(6) }
    kind 0
    source nil
    alias_id nil
  end
end
