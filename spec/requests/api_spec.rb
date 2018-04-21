require 'rails_helper'

RSpec.describe 'Api', type: :request do

  # let!(:translator_without_beta) { FactoryGirl.create(:translator) }
  let!(:translator_with_beta) { FactoryGirl.create(:translator, beta_user: true) }
  let!(:translator_without_beta) { FactoryGirl.create(:translator) }

  let!(:headers) { { 'CONTENT_TYPE' => 'application/json', 'ACCEPT' => 'application/json' } }

  describe 'POST /api/authenticate' do

    it 'should succeed with valid translator with beta access' do
      post api_authenticate_path, { email: translator_with_beta.email, password: '123456' }.to_json, headers
      expect(response).to have_http_status(200)
      json = ActiveSupport::JSON.decode(response.body)
      expect(json['auth_token']).to be_kind_of(String)
      expect(json['auth_token'].length).to be > 6
    end

    it 'should succeed with valid translator without beta access' do
      post api_authenticate_path, { email: translator_without_beta.email, password: '123456' }.to_json, headers
      expect(response).to have_http_status(401)
    end

    it 'should with wrong password' do
      post api_authenticate_path, { email: translator_with_beta.email, password: 'invalid_password' }.to_json, headers
      expect(response).to have_http_status(401)
    end

    it 'should be able to autheticate with valid token' do
      token = FactoryGirl.create(:user_token, user_id: translator_with_beta.id).token
      post api_authenticate_path, { token: token }.to_json, headers
      expect(response).to have_http_status(200)
      json = ActiveSupport::JSON.decode(response.body)
      expect(json['auth_token']).to be_kind_of(String)
      expect(json['auth_token'].length).to be > 6
    end

    it 'should not be able to autheticate with expired token' do
      token = FactoryGirl.create(:user_token, user_id: translator_with_beta.id, created_at: (UserToken::TOKEN_VALID_FOR + 1.minute).ago).token
      post api_authenticate_path, { token: token }.to_json, headers
      expect(response).to have_http_status(401)
    end

    it 'should not be able to autheticate with invalid token' do
      token = 'something'
      post api_authenticate_path, { token: token }.to_json, headers
      expect(response).to have_http_status(401)
    end

  end
end
