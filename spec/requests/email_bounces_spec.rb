require 'rails_helper'

RSpec.describe 'Amazon SES notifications', type: :request do
  let!(:client) do
    FactoryGirl.create(:client, email: 'jane84@example.com', bounced: false)
  end

  context 'with valid parameters' do
    describe 'hard bounce processing' do
      let(:valid_attributes) do
        '{
          "notificationType": "Bounce",
          "bounce": {
            "bounceType": "Permanent",
            "bounceSubType": "General",
            "bouncedRecipients": [
              {
                "emailAddress": "jane84@example.com"
              },
              {
                "emailAddress": "richard@example.com"
              }
            ],
            "timestamp": "2016-01-27T14:59:38.237Z",
            "feedbackId": "00000137860315fd-869464a4-8680-4114-98d3-716fe35851f9-000000",
            "remoteMtaIp": "127.0.2.0"
          }
        }'
      end

      before(:each) do
        post api_email_bounces_path, valid_attributes
      end

      it 'returns a success HTTP status code' do
        expect(response).to have_http_status(200)
      end

      it 'blacklists the recipient' do
        expect(client.reload.bounced).to be true
      end
    end

    describe 'soft bounce processing' do
      let(:valid_attributes) do
        '{
              "notificationType": "Bounce",
              "bounce": {
                "bounceType": "Transient",
                "bounceSubType": "General",
                "bouncedRecipients": [
                  {
                    "emailAddress": "jane84@example.com"
                  },
                  {
                    "emailAddress": "richard@example.com"
                  }
                ],
                "timestamp": "2016-01-27T14:59:38.237Z",
                "feedbackId": "00000137860315fd-869464a4-8680-4114-98d3-716fe35851f9-000000",
                "remoteMtaIp": "127.0.2.0"
              }
            }'
      end

      before(:each) do
        post api_email_bounces_path, valid_attributes
      end

      it 'returns a success HTTP status code' do
        expect(response).to have_http_status(200)
      end

      it 'does not blacklist the recipient' do
        expect(client.reload.bounced).to be_falsey
      end
    end

    describe 'complaint processing' do
      let(:valid_attributes) do
        '{
          "notificationType":"Complaint",
          "complaint":{
            "complainedRecipients":[
              {
                "emailAddress":"jane84@example.com"
              }
            ],
            "timestamp":"2016-01-27T14:59:38.237Z",
            "feedbackId":"0000013786031775-fea503bc-7497-49e1-881b-a0379bb037d3-000000"
          }
        }'
      end

      before(:each) do
        post api_email_bounces_path, valid_attributes
      end

      it 'returns a success HTTP status code' do
        expect(response).to have_http_status(200)
      end

      it 'blacklists the recipient' do
        expect(client.reload.bounced).to be true
      end
    end
  end

  context 'with invalid parameters' do
    before(:each) do
      post api_email_bounces_path, '{ "invalid": "json attributes" }'
    end

    it 'returns a bad request HTTP status code' do
      expect(response).to have_http_status(400)
    end
  end
end
