require 'rails_helper'

describe HelpGroup do
  context 'validations' do
    shared_examples 'has_base_validation_error' do
      it 'has validation error' do
        help_group.valid?
        expect(help_group.errors[field].first).to eq(message)
      end
    end

    context 'presence' do
      %w(order name).each do |field|
        let(:help_group) { build(:help_group, field.to_sym => nil) }
        let(:message) { 'can\'t be blank' }
        let(:field) { field.to_sym }
        include_examples 'has_base_validation_error'
      end
    end

    context 'uniqueness' do
      %w(order name).each do |field|
        let(:help_group2) { create(:help_group) }
        let(:help_group) { build(:help_group, field.to_sym => help_group2.try(field.to_sym)) }
        let(:message) { 'has already been taken' }
        let(:field) { field.to_sym }
        include_examples 'has_base_validation_error'
      end
    end
  end
end
