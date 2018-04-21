FactoryGirl.define do
  factory :notice, class: SiteNotice do
    txt { Faker::Lorem.words(10).join(' ') }
    active 0
    start_time { Time.now }
    end_time { Time.now + 7.days }
  end
end
