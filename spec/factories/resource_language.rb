FactoryGirl.define do
  factory :resource_language, class: ResourceLanguage do
    translation_amount 0.08
    transient do
      account_balance 0
    end

    factory :resource_language_with_strings do
      transient do
        strings_count 5
      end

      after(:create) do |resource_language, evaluator|
        create_list(:resource_string, evaluator.strings_count, resource_language: [resource_language])
      end
    end

    trait :with_account do
      after(:create) do |resource_language, evaluator|
        create(
          :resource_language_account,
          owner_id: resource_language.id,
          balance: evaluator.account_balance
        )
      end
    end
  end
end
