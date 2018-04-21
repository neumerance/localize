require 'rails_helper'

describe HelpPlacement do
  context 'validations' do
    shared_examples 'has_base_validation_error' do
      it 'has validation error' do
        help_placement.valid?
        expect(help_placement.errors[field].first).to eq(message)
      end
    end

    context 'valid url' do
      let(:help_placement) { build(:help_placement, url: Faker::Crypto.md5) }
      let(:message) { 'must begin with HTTP:// or HTTPS://' }
      let(:field) { :url }
      include_examples 'has_base_validation_error'
    end

    context 'presence of url' do
      let(:help_placement) { build(:help_placement, url: nil) }
      let(:message) { 'can\'t be blank' }
      let(:field) { :url }
      include_examples 'has_base_validation_error'
    end

    context 'presence of action and controller' do
      let(:help_placement) { create(:help_placement) }
      it 'should have controller' do
        expect(help_placement.controller).to eq('users')
      end

      it 'should have action' do
        expect(help_placement.action).to eq('new')
      end
    end
  end
end
