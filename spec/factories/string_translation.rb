FactoryGirl.define do
  factory :string_translation, class: StringTranslation do
    language_id 1
    txt { Faker::Lorem.words(2).join(' ') }
    resource_string
  end
end
