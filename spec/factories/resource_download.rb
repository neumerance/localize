FactoryGirl.define do
  factory :resource_download, class: ResourceDownload do
    type 'ResourceDownload'
    association :text_resource, factory: :text_resource, strategy: :find_or_create
    description { Faker::Lorem.word }
    content_type 'application/octet-stream'
    filename 'file.gz'
    status 1
    after :build do |rd|
      rd.set_contents 'Test'
    end
  end
end
