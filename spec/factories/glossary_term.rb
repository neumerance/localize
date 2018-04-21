FactoryGirl.define do
  factory :glossary_term, class: GlossaryTerm do
    association :language, factory: :english_language, strategy: :find_or_create
    txt { Faker::Lorem.words(5).join(' ') }
    description { Faker::Lorem.words(5).join(' ') }
  end
end
