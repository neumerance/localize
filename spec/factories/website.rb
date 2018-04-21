FactoryGirl.define do
  factory :website, class: Website do
    name 'Web project'
    description { Faker::Lorem.words(10).join(' ') }
    platform_kind 2
    url { Faker::Internet.url }
    pickup_type 1
    accesskey_ok 1
    project_kind 2
    cms_description { Faker::Lorem.words(10).join(' ') }
    free_support 1
    accesskey { Faker::Crypto.md5 }
    anon 1

    trait :with_offer do
      after(:create) do |website|
        FactoryGirl.create(:website_translation_offer, :with_language_pair_fixed_price, website: website)
      end
    end

    trait :english_to_german_language_pair_offer do
      after(:create) do |website|
        FactoryGirl.create(:website_translation_offer, :with_managed_work, website: website, from_language_id: 1, to_language_id: 3)
      end
    end

    trait :with_contract do
      # Also apply the :with_offer trait, as website_translation_contract
      # belongs_to website_translation_offer
      with_offer
      after(:create) do |website|
        FactoryGirl.create(
          :website_translation_contract,
          website_translation_offer: website.website_translation_offers.first
        )
      end
    end

    factory :website_with_client do
      association :client, factory: :client
      after(:create) do |website|
        FactoryGirl.create(:website_translation_offer, website: website)
      end
    end
  end
end
