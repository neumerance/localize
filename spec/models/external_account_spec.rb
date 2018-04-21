require 'rails_helper'

describe ExternalAccount do
  context 'validations' do
    shared_examples 'has_base_validation_error' do
      it 'has validation error' do
        external_account.valid?
        expect(external_account.errors[field].first).to eq(message)
      end
    end

    context 'valid identifier' do
      let(:external_account) { build(:external_account_paypal, identifier: Faker::Crypto.md5) }
      let(:message) { 'must be a valid email address' }
      let(:field) { :identifier }
      include_examples 'has_base_validation_error'
    end

    context 'unique identifier' do
      let(:external_account_2) { create(:external_account_paypal) }
      let(:external_account) { build(:external_account_paypal, identifier: external_account_2.identifier) }
      let(:message) { 'An identical account already exists' }
      let(:field) { :identifier }
      include_examples 'has_base_validation_error'
    end
  end
end
