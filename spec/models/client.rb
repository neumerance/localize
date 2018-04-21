require 'rails_helper'

RSpec.describe Client, type: :model do
  let(:client) { FactoryGirl.create(:client, api_key: nil) }

  describe '#generate_api_key' do
    it 'automatically generates an API key when a new client is created' do
      expect(client.api_key.size).to eq 36
    end

    it 'creates a new API key for an existing client' do
      expect { client.change_api_key }.to \
        change { client.api_key }
      expect(client.api_key.size).to eq 36
    end
  end
end
