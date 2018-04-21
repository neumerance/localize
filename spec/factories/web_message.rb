FactoryGirl.define do
  factory :web_message, class: WebMessage do
    visitor_language_id 4
    client_language_id 1
    association :owner, factory: :client
    association :user, factory: :client
    owner_id 100043
    owner_type 'User'
    user_id 100043
    visitor_body 'Nouveau projet instantané Nouveau projet instantan...'
    client_body 'New Instant Project New Instant Project'
    word_count 6
    money_account_id 293174
    translator_id 100046
    translation_status TRANSLATION_NEEDED
    name 'Instant Project'
    comment 'normal'
    old_format 0
    notified 0
    complex_flag_users nil
  end
end
