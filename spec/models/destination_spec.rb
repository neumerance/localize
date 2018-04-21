require 'rails_helper'

describe Branding do
  context 'validations' do
    shared_examples 'has_base_validation_error' do
      it 'has validation error' do
        destination.valid?
        expect(destination.errors[field].first).to eq(message)
      end
    end

    context 'presence' do
      %w(url name).each do |field|
        let(:destination) { build(:destination, field.to_sym => nil) }
        let(:message) { 'can\'t be blank' }
        let(:field) { field.to_sym }
        include_examples 'has_base_validation_error'
      end
    end

    context 'unique' do
      let(:destination2) { create(:destination) }
      %w(url name).each do |field|
        let(:destination) { build(:destination, field.to_sym => destination2.try(field.to_sym)) }
        let(:message) { 'has already been taken' }
        let(:field) { field.to_sym }
        include_examples 'has_base_validation_error'
      end
    end

  end
end
