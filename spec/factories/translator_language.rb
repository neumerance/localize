FactoryGirl.define do
  factory :translator_language, class: TranslatorLanguage do
    status 3
    description { Faker::Lorem.words(6).join(' ') }

    factory :translate_from_english, class: 'TranslatorLanguageFrom' do
      type 'TranslatorLanguageFrom'
      association :language, factory: :english_language, strategy: :find_or_create
    end

    factory :translate_to_french, class: 'TranslatorLanguageTo' do
      type 'TranslatorLanguageTo'
      association :language, factory: :french_language, strategy: :find_or_create
    end

    factory :translate_to_german, class: 'TranslatorLanguageTo' do
      type 'TranslatorLanguageTo'
      association :language, factory: :german_language, strategy: :find_or_create
    end

  end
end
