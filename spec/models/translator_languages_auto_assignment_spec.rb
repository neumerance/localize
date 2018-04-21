require 'rails_helper'

RSpec.describe TranslatorLanguagesAutoAssignment, type: :model do
  let(:translator) { create(:translator) }
  let!(:language_pair) { create(:translator_languages_auto_assignment, translator: translator) }

  context 'validation' do
    shared_examples 'has_base_validation_error' do
      it 'has validation error' do
        language_pair2.valid?
        expect(language_pair2.errors[field].first).to eq(message)
      end
    end

    context 'uniqueness' do
      let(:language_pair2) { build(:translator_languages_auto_assignment, translator: translator) }
      let(:message) { 'has already been taken' }
      let(:field) { :translator }
      include_examples 'has_base_validation_error'
    end

    describe '#validate_min_price_per_word' do
      context 'should not allow amounts below min amount' do
        let(:language_pair2) { build(:translator_languages_auto_assignment, min_price_per_word: 0.01) }
        let(:message) { 'You cannot enter a rate below 0.09 USD / word.' }
        let(:field) { :min_price_per_word }
        include_examples 'has_base_validation_error'
      end

      context 'should not allow amounts above 10 times minimum amount' do
        let(:language_pair2) { build(:translator_languages_auto_assignment, min_price_per_word: 101) }
        let(:message) { 'You cannot enter a rate above 0.90 USD / word.' }
        let(:field) { :min_price_per_word }
        include_examples 'has_base_validation_error'
      end
    end
  end
end
