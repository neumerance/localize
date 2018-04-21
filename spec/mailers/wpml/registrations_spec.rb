require 'rails_helper'

RSpec.describe Wpml::RegistrationsMailer, type: :mailer do
  describe 'welcome' do
    let(:client) { FactoryGirl.create(:client) }
    let(:mail) { Wpml::RegistrationsMailer.welcome(client) }

    it 'renders the headers' do
      expect(mail.subject).to eq('Your new ICanLocalize account')
      expect(mail.to).to eq([client.email])
      expect(mail.from).to eq([RAW_EMAIL_SENDER])
    end

    it 'renders the body' do
      expect(mail.body.encoded).to include(client.api_key)
      expect(mail.body.encoded).to include(client.password)
    end
  end
end
