require 'rails_helper'

describe ResourceString do

  describe '#max_width_in_chars' do
    it 'should return nil if string has not max width' do
      rs = build(:resource_string, max_width: nil)
      expect(rs.max_width_in_chars).to be_nil
    end

    it 'should return max valid char lengh' do
      rs = build(:resource_string, max_width: 150, txt: '1234567890')
      expect(rs.max_width_in_chars).to eq(15)
    end
  end

  context 'Dependent destroy on string_translation.issue' do
    let(:text_resource) { create(:text_resource) }
    let(:resource_string) { create(:resource_string, txt: Faker::Lorem.words(3).join(' '), text_resource: text_resource) }
    let(:string_translation) { create(:string_translation, resource_string: resource_string) }
    let(:issue) { create(:issue, owner_type: 'StringTranslation', owner_id: string_translation.id) }

    it 'should able to delete resource string with string translation issue' do
      resource_string.destroy
      expect { resource_string.reload }.to raise_error ActiveRecord::RecordNotFound
    end

    context 'validations' do
      shared_examples 'has_base_validation_error' do
        it 'has validation error' do
          resource_string.valid?
          expect(resource_string.errors[field].first).to eq(message)
        end
      end

      context 'presence' do
        %w(token txt).each do |field|
          let(:resource_string) { build(:resource_string, field.to_sym => nil) }
          let(:message) { 'can\'t be blank' }
          let(:field) { field.to_sym }
          include_examples 'has_base_validation_error'
        end
      end

      context 'max width' do
        let(:resource_string) { build(:resource_string, max_width: 49) }
        let(:message) { 'cannot be smaller than 50 percent' }
        let(:field) { :max_width }
        include_examples 'has_base_validation_error'
      end
    end
  end

end
