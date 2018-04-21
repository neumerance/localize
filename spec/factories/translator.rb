FactoryGirl.define do
  factory :translator, class: Translator do
    sequence(:nickname) { |n| "#{Faker::Internet.unique.user_name}#{n}" }
    sequence(:email) { |n| Faker::Internet.unique.email.gsub('@', "#{n}@") }
    password '123456'
    fname { Faker::Name.first_name }
    lname { Faker::Name.last_name }
    userstatus 2
    type 'Translator'

    factory :beta_translator do
      beta_user true
    end

    after(:create) do |trls|
      FactoryGirl.create(:translate_from_english, translator: trls)
      FactoryGirl.create(:translate_to_french, translator: trls)
      FactoryGirl.create(:translate_to_german, translator: trls)
    end

    trait :translator_languages_auto_assignment do
      after(:create) do |translator|
        FactoryGirl.create(:translator_languages_auto_assignment, translator: translator, from_language_id: 1, to_language_id: 3)
      end
    end

  end
end
