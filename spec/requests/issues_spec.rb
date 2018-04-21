require 'rails_helper'
require 'support/utils_helper'

RSpec.describe 'Issues', type: :request do
  include UtilsHelper

  let!(:client) { FactoryGirl.create(:client) }
  let!(:translator) { FactoryGirl.create(:translator) }
  let!(:beta_translator) { FactoryGirl.create(:beta_translator) }
  let!(:website) { FactoryGirl.create(:website, client_id: client.id) }
  let!(:cms_request) { FactoryGirl.create(:cms_request, website_id: website.id) }
  let!(:cms_target_language) { FactoryGirl.create(:cms_target_language, cms_request_id: cms_request.id, translator_id: translator.id) }

  let!(:request_data) do
    {
      data: {
        type: 'support_ticket',
        attributes: {
          accesskey: website.accesskey,
          subject: 'Issue with translation of some_page',
          message_body: 'Some interesting description bla bla bla',
          callback_url: 'http://example.com/some/callback/url'
        },
        relationships: {
          cms_request: {
            data: {
              type: 'cms_request',
              id: cms_request.id
            }
          },
          website: {
            data: {
              type: 'website',
              id: website.id
            }
          }
        }
      }
    }
  end

  let!(:valid_json) do
    request_data.to_json
  end

  let!(:headers) { { 'CONTENT_TYPE' => 'application/json', 'ACCEPT' => 'application/json' } }

  describe 'POST /api/issues' do

    it 'should succeed with valid json' do
      post api_issues_path, valid_json, headers
      expect(response).to have_http_status(200)
    end

    it 'should create a new issue and message with valid json' do
      issues_count = Issue.count
      messages_count = Message.count
      post api_issues_path, valid_json, headers
      expect(Issue.count).to eq(issues_count + 1)
      expect(Message.count).to eq(messages_count + 1)
    end

    it 'should fail with empty json' do
      post api_issues_path, {}.to_json, headers
      error_response = JSON.parse(response.body)['errors'].first
      expect(error_response['status']).to eq(400)
      expect(error_response['title']).to eq('UNEXPECTED ERROR')
    end

    it 'should show error with wrong cms request id' do
      invalid_params = request_data
      invalid_params[:data][:relationships][:cms_request][:data][:id] = 0
      post api_issues_path, invalid_params.to_json, headers
      error_response = JSON.parse(response.body)['errors'].first
      expect(error_response['status']).to eq(404)
      expect(error_response['title']).to eq('NOT FOUND')
      expect(error_response['message']).to eq('CmsRequest with ID: 0 was not found')
    end

    it 'should show error with wrong website id' do
      invalid_params = request_data
      invalid_params[:data][:relationships][:website][:data][:id] = 0
      post api_issues_path, invalid_params.to_json, headers
      error_response = JSON.parse(response.body)['errors'].first
      expect(error_response['status']).to eq(400)
      expect(error_response['title']).to eq('DATA MISSMATCH')
      expect(error_response['message']).to eq("CmsRequest with id: #{cms_request.id} does not belong to Website with id: 0")
    end

    it 'should not allow issues without a message body' do
      invalid_params = request_data
      invalid_params[:data][:attributes][:message_body] = ''
      post api_issues_path, invalid_params.to_json, headers
      error_response = JSON.parse(response.body)['errors'].first
      expect(error_response['status']).to eq(400)
      expect(error_response['title']).to eq('INVALID DATA')
      expect(error_response['message']).to eq('Message body is required, but it was empty')
    end

    it 'should not allow with wrong accesskey' do
      invalid_params = request_data
      invalid_params[:data][:attributes][:accesskey] = 'bad_access_key'
      post api_issues_path, invalid_params.to_json, headers
      error_response = JSON.parse(response.body)['errors'].first
      expect(error_response['status']).to eq(403)
      expect(error_response['title']).to eq('FORBIDDEN')
      expect(error_response['message']).to eq("Authentication using accesskey 'bad_access_key' failed for CmsRequest with ID: #{cms_request.id}")
    end

    it 'should accept ids as string' do
      invalid_params = request_data
      invalid_params[:data][:relationships][:cms_request][:data][:id] = cms_request.id.to_s
      invalid_params[:data][:relationships][:website][:data][:id] = website.id.to_s
      issues_count = Issue.count
      messages_count = Message.count
      post api_issues_path, invalid_params.to_json, headers
      expect(Issue.count).to eq(issues_count + 1)
      expect(Message.count).to eq(messages_count + 1)
    end

    it 'should create new issue when cms_request with authentication' do
      post api_issues_path, valid_json, headers
      issue = Issue.last
      json_response = JSON.parse(response.body)
      expect(issue.id).to eq(json_response['data']['id'])
      expect(issue.owner.id).to eq(request_data[:data][:relationships][:cms_request][:data][:id])
      expect(issue.initiator).to eq(client)
      expect(issue.kind).to eq(ISSUE_INCORRECT_TRANSLATION)
      expect(issue.title).to eq(request_data[:data][:attributes][:subject])
      expect(issue.target).to eq(translator)
    end
  end

  describe 'GET /api/issues/id' do

    it 'should return not found for non existing issue' do
      get api_issue_path(0)
      error_response = JSON.parse(response.body)
      expect(error_response['code']).to eq(404)
      expect(error_response['message']).to eq('Issue with ID: 0 was not found')
    end

    it 'should return newly created issue' do
      post api_issues_path, valid_json, headers
      issue_id = JSON.parse(response.body)['data']['id']
      get api_issue_path(issue_id)
      issue = JSON.parse(response.body)
      expect(issue['data']['id']).to eq(issue_id)
      expect(issue['data']['type']).to eq(request_data[:data][:type])
      expect(issue['data']['attributes']['status']).to eq('Issue open')
      expect(issue['data']['attributes']['subject']).to eq(request_data[:data][:attributes][:subject])
      expect(issue['data']['attributes']['message']).to eq(request_data[:data][:attributes][:message_body])
      expect(issue['data']['links']['self']).to include(issue_path(issue_id))
    end

  end

end
