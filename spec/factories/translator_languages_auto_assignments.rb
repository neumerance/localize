FactoryGirl.define do
  factory :translator_languages_auto_assignment do
    association(:translator, factory: :translator)

    association :from_language,
                factory: :english_language,
                strategy: :find_or_create

    association :to_language,
                factory: :french_language,
                strategy: :find_or_create

    min_price_per_word '0.09'
  end
end
