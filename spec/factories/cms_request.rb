FactoryGirl.define do
  factory :cms_request, class: CmsRequest do
    status 4
    association :language, factory: :english_language, strategy: :find_or_create
    title { Faker::Lorem.words(2).join(' ') }
    permlink { Faker::Internet.url }
    cms_id { Faker::Lorem.word }
    tas_url nil
    tas_port nil
    list_type 'shop'
    list_id 5
    last_operation nil
    error_description nil
    delivered nil
    note nil
    idkey nil
    container 'example_container'
    notified 1
    tp_id nil
    xliff_processed true
    pending_tas false

    word_count 100

    factory :cms_request_translated do
      status 5
    end

    factory :cms_request_done do
      status 6
    end

    trait :with_dependencies do
      after(:create) do |cms|
        website = FactoryGirl.create(:website, :with_contract,
                                     cms_requests: [cms])
        project = FactoryGirl.create(:project, client: cms.website.client)
        FactoryGirl.create(:cms_target_language, cms_request: cms)
        FactoryGirl.create(:translator,
                           cms_target_languages: [cms.cms_target_language],
                           website_translation_contracts: [website.website_translation_contracts.first])
        FactoryGirl.create(:revision,
                           cms_request: cms,
                           client: cms.website.client,
                           project: project)
        FactoryGirl.create(:revision_language, revision: cms.revision)
        FactoryGirl.create(:chat, revision: cms.revision)
        FactoryGirl.create(:bid, :won, :accepted, :with_bid_account,
                           revision_language: cms.revision.revision_languages.last,
                           chat: cms.revision.chats.last)
        FactoryGirl.create(:managed_work,
                           :waiting_for_payment,
                           owner_id: cms.revision.revision_languages.last.id,
                           owner_type: 'RevisionLanguage',
                           client_id: cms.website.client.id)
      end
    end
  end
end
