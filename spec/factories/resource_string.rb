FactoryGirl.define do
  factory :resource_string, class: ResourceString do
    text_resource_id 101
    token { Faker::Crypto.md5 }
    txt { Faker::Lorem.words(5).join(' ') }
    comment { Faker::Lorem.words(5).join(' ') }
    context 'icanlocalize.pot'
    max_width 80

    factory :resource_strings_with_string_translations do
      after(:create) do |resource_string, _evaluator|
        create :string_translation, resource_string: resource_string
      end

    end
  end
end
