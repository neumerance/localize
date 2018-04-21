require 'rails_helper'

describe HelpTopic do
  context 'validations' do
    shared_examples 'has_base_validation_error' do
      it 'has validation error' do
        help_topic.valid?
        expect(help_topic.errors[field].first).to eq(message)
      end
    end

    context 'valid url' do
      let(:help_topic) { build(:help_topic, url: Faker::Crypto.md5) }
      let(:message) { 'must begin with HTTP:// or HTTPS://' }
      let(:field) { :url }
      include_examples 'has_base_validation_error'
    end

    context 'presence of url' do
      %w(url title summary).each do |field|
        let(:help_topic) { build(:help_topic, field.to_sym => nil) }
        let(:message) { 'can\'t be blank' }
        let(:field) { field.to_sym }
        include_examples 'has_base_validation_error'
      end
    end
  end
end
