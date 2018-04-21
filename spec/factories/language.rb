FactoryGirl.define do
  factory :language, class: Language do
    major 1
    scanned_for_translators 0
    rtl 0

    factory :english_language do
      id 1
      name 'English'
      iso 'en'
    end

    factory :french_language do
      id 2
      name 'French'
      iso 'fr'
    end

    factory :german_language do
      id 3
      name 'German'
      iso 'de'
    end
  end
end
