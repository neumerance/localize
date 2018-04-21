FactoryGirl.define do
  factory :resource_upload, class: ResourceUpload do
    type 'ResourceUpload'
    association :text_resource, factory: :text_resource, strategy: :find_or_create
    description { Faker::Lorem.word }
    content_type 'application/octet-stream'
    filename 'file.gz'
    status 1
    after :build do |ru|
      ru.set_contents 'key=value'
    end
  end
end
