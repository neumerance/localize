FactoryGirl.define do
  factory :language_pair_fixed_price do
    # In order to create a valid language_pair_fixed_price record, first
    # we need to create two languages for the from_language and to_language
    # associations. Every time a new Language is created, a callback in
    # the Language model creates multiple language_pair_fixed_price records by
    # combining the new language with all preexisting languages. We need to
    # avoid that when creating associated languages in this factory, or else we
    # will get an uniqueness validation error as any language_pair_fixed_price
    # this factory may attempt to create will already exist.
    association :from_language,
                factory: :english_language,
                skip_language_pairs_creation: true
    association :to_language,
                factory: :french_language,
                skip_language_pairs_creation: true
    actual_price MINIMUM_FIXED_PRICE
    published true

    transient do
      # This transient attribute is used to create two associated contracts
      # that result in a specific average price.
      average_contract_price 0.12
    end

    trait :with_contracts_and_offer do
      after(:create) do |language_pair, evaluator|
        contract1 = FactoryGirl.create(
          :website_translation_contract,
          status: 2,
          amount: evaluator.average_contract_price - 0.01
        )
        contract2 = FactoryGirl.create(
          :website_translation_contract,
          status: 2,
          amount: evaluator.average_contract_price + 0.01,
          translator: FactoryGirl.create(:translator)
        )
        FactoryGirl.create(
          :website_translation_offer,
          from_language: language_pair.from_language,
          to_language: language_pair.to_language,
          website_translation_contracts: [contract1, contract2]
        )
      end
    end
  end
end
