FactoryGirl.define do
  factory :glossary_translation, class: GlossaryTranslation do
    txt { Faker::Lorem.words(5).join(' ') }
  end
end
