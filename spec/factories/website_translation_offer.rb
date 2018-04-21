FactoryGirl.define do
  factory :website_translation_offer, class: WebsiteTranslationOffer do
    website_id 1
    from_language_id 1
    to_language_id 3
    url { Faker::Internet.url }
    sample_text { Faker::Lorem.words(10).join(' ') }

    after(:create) do |offer|
      FactoryGirl.create(:managed_work, owner_id: offer.id, owner_type: 'WebsiteTranslationOffer')
    end
  end

  trait :with_language_pair_fixed_price do
    before(:create) do |offer|
      language_pair = LanguagePairFixedPrice.where(language_pair_id: "#{offer.from_language_id}_#{offer.to_language_id}").first
      FactoryGirl.create(:language_pair_fixed_price, from_language_id: offer.from_language_id, to_language_id: offer.to_language_id) unless language_pair.present?
    end
  end

  trait :with_managed_work do
    association :managed_work, factory: :managed_work, strategy: :create
  end

end
