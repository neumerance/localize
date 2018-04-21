require 'spec_helper'
require 'rails_helper'

describe Api::V1::ApiController, type: :controller do
  include ActionDispatch::TestProcess

  describe 'quote' do
    before(:each) do
      allow(double('Docsplit')).to receive(:extract_text)
      allow(double('File')).to receive(:read) { 'test ' * 2 }
    end

    it 'respond' do
      post :quote, params: { file: fixture_file_upload('files/bidding/test.txt') }
      expect(response).to have_http_status(:success)
    end

    context 'plain text file' do
      it 'return 200' do
        post('quote', params: { file: fixture_file_upload('files/bidding/test.txt') })
        expect(response).to have_http_status(:success)
      end

      it 'be successful' do
        response = post('quote', params: { file: fixture_file_upload('files/bidding/test.txt') })
        json = ActiveSupport::JSON.decode(response.body)
        expect(json['status']).to eq('success')
      end

      it 'have a word count' do
        response = post('quote', params: { file: fixture_file_upload('files/bidding/test.txt') })
        json = ActiveSupport::JSON.decode(response.body)
        expect(json['wordCount']).to eq(2)
      end

      it 'have a quote' do
        response = post('quote', params: { file: fixture_file_upload('files/bidding/test.txt') })
        json = ActiveSupport::JSON.decode(response.body)
        expect(json['quote']).to eq(0.18)
      end

      it 'have a format' do
        response = post('quote', params: { file: fixture_file_upload('files/bidding/test.txt') })
        json = ActiveSupport::JSON.decode(response.body)
        expect(json['fileType']).to eq(ZippedFile.format_name_for('.txt'))
      end
    end

    context 'unsupported file' do
      it 'return 200' do
        post('quote', params: { file: fixture_file_upload('files/empty.foobar') })
        expect(response).to have_http_status(:success)
      end

      it 'fail' do
        response = post('quote', params: { file: fixture_file_upload('files/empty.foobar') })
        json = ActiveSupport::JSON.decode(response.body)
        expect(json['status']).to eq('fail')
      end

      it 'have a message' do
        response = post('quote', params: { file: fixture_file_upload('files/empty.foobar') })
        json = ActiveSupport::JSON.decode(response.body)
        expect(json['message']).to be_kind_of(String)
        expect(json['message'].length).to be > 6
      end
    end

    context 'empty file' do
      it 'return 200' do
        post('quote')
        expect(response).to have_http_status(:success)
      end

      it 'be an error' do
        response = post('quote')
        json = ActiveSupport::JSON.decode(response.body)
        expect(json['status']).to eq('error')
      end
    end
  end

  describe 'token_authentication' do
    context 'check token authentication' do

      it 'should allow valid user to get token' do
        @user = FactoryGirl.create(:translator, beta_user: true)
        post('authenticate', params: { email: @user.email, password: @user.password })
        expect(response).to have_http_status(:success)
        json = ActiveSupport::JSON.decode(response.body)
        expect(json['auth_token']).to be_kind_of(String)
        expect(json['auth_token'].length).to be > 6
      end

      it 'should not allow authenticate invalid user' do
        @user = FactoryGirl.create(:translator, beta_user: true)
        post('authenticate', params: { email: @user.email, password: '' })
        expect(response).to have_http_status(:unauthorized)
        json = ActiveSupport::JSON.decode(response.body)
        expect(json['auth_token']).to be_nil
      end

      it 'should allow requests with token to authenticate' do
        @user = FactoryGirl.create(:translator, beta_user: true)
        post('authenticate', params: { email: @user.email, password: @user.password })
        expect(response).to have_http_status(:success)
        json = ActiveSupport::JSON.decode(response.body)
        @token = json['auth_token']
        request.headers['Authorization'] = @token
        post('test_api_request')
        expect(response).to have_http_status(:success)
        json = ActiveSupport::JSON.decode(response.body)
        expect(json['all_ok']).to be_truthy
      end

      it 'should not allow requests with wrong token' do
        post('test_api_request')
        expect(response).to have_http_status(:unauthorized)
        json = ActiveSupport::JSON.decode(response.body)
        expect(json['all_ok']).to be_nil
      end

      it 'should not allow non beta users' do
        @user = FactoryGirl.create(:translator)
        post('authenticate', params: { email: @user.email, password: @user.password })
        expect(response).to have_http_status(:unauthorized)
      end

      it 'should not allow non translators' do
        @user = FactoryGirl.create(:user)
        post('authenticate', params: { email: @user.email, password: @user.password })
        expect(response).to have_http_status(:unauthorized)
      end

    end
  end

end
