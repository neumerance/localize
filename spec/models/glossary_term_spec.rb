require 'rails_helper'

describe GlossaryTerm do
  context 'validations' do
    %w(txt description).each do |field|
      context "validate #{field}" do
        let(:glossary_term) { build(:glossary_term, field.to_sym => Faker::Lorem.words(COMMON_FIELD / 4).join(' ')) }

        it "should not allow client body length more than #{COMMON_FIELD}" do
          glossary_term.valid?
          expect(glossary_term.errors[field.to_sym].first).to eq("is too long (maximum is #{COMMON_FIELD} characters)")
        end
      end
    end
  end
end
