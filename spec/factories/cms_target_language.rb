FactoryGirl.define do
  factory :cms_target_language, class: CmsTargetLanguage do
    association :language, factory: :french_language, strategy: :find_or_create
    status 2
    lock_version 0
    title nil
    permlink nil
    delivered nil
    word_count nil
    money_account_id nil
  end
end
