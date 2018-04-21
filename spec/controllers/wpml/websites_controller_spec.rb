require 'rails_helper'

RSpec.describe Wpml::WebsitesController, type: :controller do

  describe 'WPML 3.9 changes' do
    let(:client) { FactoryGirl.create(:client) }
    let(:website) { FactoryGirl.create(:website, client_id: client.id) }

    context 'GET #token' do

      it 'should get token with right paramms' do
        get :token, id: website.id, accesskey: website.accesskey, format: :json
        expect(response).to have_http_status(:success)
        json = JSON.parse(response.body).symbolize_keys
        expect(json[:api_token]).to eq(website.client.api_key)
      end

      it 'should respond with 404 for invalid website id' do
        get :token, id: 0, accesskey: website.accesskey, format: :json
        expect(response).to have_http_status(:not_found)
      end

      it 'should respond with 404 for invalid accesskey' do
        get :token, id: website.id, accesskey: 'not_valid', format: :json
        expect(response).to have_http_status(:not_found)
      end

    end

    context 'POST #migrated' do
      it 'should update website api_version and respond with 200' do
        expect(website.api_version).to be_nil
        post :migrated, id: website.id, accesskey: website.accesskey, format: :json
        expect(response).to have_http_status(:success)
        expect(website.reload.api_version).to eq '2.0'
      end

    end

  end

end
