FactoryGirl.define do
  factory :revision, class: Revision do
    association :project, factory: :project
    description { Faker::Lorem.paragraph }
    association :language, factory: :english_language, strategy: :find_or_create
    name { Faker::Name.name }
    released 0
    max_bid 0.0
    max_bid_currency 1
    bidding_duration nil
    project_completion_duration 3
    release_date nil
    bidding_close_time nil
    alert_status 0
    private_key nil
    auto_accept_amount 0.0
    kind 0
    update_counter 2
    is_test false
    notified 1
    word_count nil
    note nil
    flag false
    force_display_on_ta nil
  end

end
