FactoryGirl.define do
  factory :revision_language, class: RevisionLanguage do
    association :language, factory: :language, strategy: :find_or_create
  end
end
