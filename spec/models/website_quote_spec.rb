require 'rails_helper'

describe WebsiteQuote do
  context 'validations' do
    let(:field) { :url }

    context 'presence' do
      let(:quote) { WebsiteQuote.new(nil) }
      let(:message) { 'can\'t be blank' }

      it 'has validation error' do
        quote.valid?
        expect(quote.errors[field].first).to eq(message)
      end
    end

    context 'valid url' do
      let(:quote) { WebsiteQuote.new(Faker::Crypto.md5) }
      let(:message) { 'URL not valid' }

      it 'validates the url' do
        expect { quote }.to raise_error ActiveModel::ValidationError
      end
    end
  end
end
