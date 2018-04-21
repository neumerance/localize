require 'rails_helper'
require 'support/utils_helper'

RSpec.describe 'WebtaIssues', type: :request do
  include UtilsHelper

  let!(:client) { FactoryGirl.create(:client, email: 'client@cl.cl') }
  let!(:translator) { FactoryGirl.create(:translator, email: 'translator@tr.tr') }
  let!(:beta_translator) { FactoryGirl.create(:beta_translator, email: 'beta_translator@tr.tr') }
  let!(:website) { FactoryGirl.create(:website, client_id: client.id) }
  let!(:cms_request) { FactoryGirl.create(:cms_request, website_id: website.id) }
  let!(:cms_target_language) { FactoryGirl.create(:cms_target_language, cms_request_id: cms_request.id, translator_id: translator.id) }
  let!(:xliff) { FactoryGirl.create(:xliff, cms_request: cms_request, uploaded_data: TempContent.new("#{Rails.root}/spec/fixtures/files/xliffs/3.xliff")) }
  let!(:xliff_trans_unit_mrk) { FactoryGirl.create(:xliff_trans_unit_mrk, cms_request: cms_request, xliff: xliff, mrk_type: XliffTransUnitMrk::MRK_TYPES[:target]) }
  let!(:xliff_trans_unit_mrk_source_type) { FactoryGirl.create(:xliff_trans_unit_mrk, cms_request: cms_request, xliff: xliff, mrk_type: XliffTransUnitMrk::MRK_TYPES[:source], target_id: xliff_trans_unit_mrk.id) }
  let!(:revision) { FactoryGirl.create(:revision, cms_request: cms_request) }
  let!(:revision_language) { FactoryGirl.create(:revision_language, revision: revision) }
  let!(:managed_work) { FactoryGirl.create(:managed_work, owner_id: revision_language.id, owner_type: 'RevisionLanguage', active: MANAGED_WORK_ACTIVE, translator_id: beta_translator.id) }
  let(:mrk_issue) { FactoryGirl.create(:issue, owner: xliff_trans_unit_mrk, status: ISSUE_OPEN, kind: 4) }

  let!(:request_data_with_mrk) do
    {
      xliff_id: cms_request.base_xliff.id,
      mrk: {
        id: xliff_trans_unit_mrk.id,
        mrk_type: XliffTransUnitMrk::MRK_TYPES[:target].to_s
      },
      issue: {
        message_body: 'Some interesting description bla bla bla',
        kind: 'ISSUE_TRANSLATION_SUGGESTION',
        target_type: 'translator'
      }
    }
  end

  let!(:request_data_for_mrk_issue) do
    {
      xliff_trans_unit_mrk: {
        data: {
          id: xliff_trans_unit_mrk.id,
          mrk_type: XliffTransUnitMrk::MRK_TYPES[:target].to_s
        }
      }
    }
  end

  let!(:valid_json_with_mrk) do
    request_data_with_mrk.to_json
  end

  let!(:token) { auth_token(beta_translator) }
  let!(:headers_with_token) { { 'CONTENT_TYPE' => 'application/json', 'ACCEPT' => 'application/json', 'Authorization' => token } }

  before(:all) do
    cms = FactoryGirl.create(:cms_request, :with_dependencies)
    cms.revision.chats.each { |chat| chat.update_attribute(:translator, @translator) }
    cms.cms_target_language.update_attribute(:translator, @translator)
    FactoryGirl.create(:xliff, cms_request: cms, uploaded_data: TempContent.new("#{Rails.root}/spec/fixtures/files/xliffs/3.xliff"))
    @translator = FactoryGirl.create(:beta_translator, capacity: 100)
    @reviewer = FactoryGirl.create(:beta_translator, capacity: 100)

    @xliff_trans_unit_mrk = FactoryGirl.create(:xliff_trans_unit_mrk, cms_request: cms)
    @issue = FactoryGirl.create(:issue, owner: @xliff_trans_unit_mrk, target: @translator, title: 'This is a title for issue', kind: ISSUE_INCORRECT_TRANSLATION, status: ISSUE_OPEN)
    @message = FactoryGirl.create(:message, owner: @issue, body: 'This is a message for issue pointing to mrk.')
    @closed_issue = FactoryGirl.create(:issue, owner: @xliff_trans_unit_mrk, target: @translator, title: 'This is a title for closed issue', kind: ISSUE_INCORRECT_TRANSLATION, status: ISSUE_CLOSED)
    @closed_issue_message = FactoryGirl.create(:message, owner: @closed_issue, body: 'This is very long message which is having more than 45 characters for closed issue pointing to mrk.')

    @bid = cms.revision.all_bids.where(won: true).first
    @bid.managed_work.update_attributes(active: MANAGED_WORK_ACTIVE, translator: @reviewer, translation_status: MANAGED_WORK_REVIEWING)
    XliffTransUnitMrk.where(xliff_id: cms.base_xliff.id).update_all(mrk_status: XliffTransUnitMrk::MRK_STATUS[:translation_completed])

    @token = auth_token(@translator)
    @headers = { 'CONTENT_TYPE' => 'application/json', 'ACCEPT' => 'application/json', 'Authorization' => @token }

    @reviewer_token = auth_token(@reviewer)
    @headers_with_reviewer = { 'CONTENT_TYPE' => 'application/json', 'ACCEPT' => 'application/json', 'Authorization' => @reviewer_token }

    cms = FactoryGirl.create(:cms_request, :with_dependencies)
    cms.revision.chats.each { |chat| chat.update_attribute(:translator, @translator) }
    cms.cms_target_language.update_attribute(:translator, @translator)
    FactoryGirl.create(:xliff, cms_request: cms, uploaded_data: TempContent.new("#{Rails.root}/spec/fixtures/files/xliffs/3.xliff"))
    mrk = cms.base_xliff.parsed_xliff.xliff_trans_units.last.xliff_trans_unit_mrks.where(mrk_type: XliffTransUnitMrk::MRK_TYPES[:target], mrk_status: XliffTransUnitMrk::MRK_STATUS[:original]).last

    bid = cms.revision.all_bids.where(won: true).first
    bid.managed_work.update_attributes(active: MANAGED_WORK_ACTIVE, translator: @reviewer)

    @valid_params = {
      xliff_id: cms.base_xliff.id,
      mrk: {
        id: mrk.id,
        mrk_type: XliffTransUnitMrk::MRK_TYPES[:target].to_s
      },
      issue: {
        message_body: 'Some interesting description bla bla bla',
        kind: 'ISSUE_TRANSLATION_SUGGESTION',
        target_type: 'translator'
      }
    }
    @cms = cms
  end

  describe 'GET /api/issues/get_by_mrk' do

    it 'should return all the issues for the mrk' do
      # create issue by invoking create API
      post create_issue_by_mrk_api_job_webta_issues_path(cms_request), valid_json_with_mrk, headers_with_token
      create_issue_response = JSON.parse(response.body)
      issue = Issue.last

      # fetch issues for particular mrk
      get get_by_mrk_api_job_webta_issues_path(cms_request.id), request_data_for_mrk_issue, headers_with_token
      issue_json = JSON.parse(response.body).first
      expect(issue_json['data']['id']).to eq(issue.id)
      expect(issue_json['data']['attributes']['subject']).to eq(issue.title)
      expect(issue_json['data']['attributes']['message']).to eq(issue.messages.first.body)
    end

    it 'should return 400 when invalid data is passed' do
      get get_by_mrk_api_job_webta_issues_path(cms_request.id), {}, headers_with_token
      error_response = JSON.parse(response.body)
      expect(error_response['code']).to eq(400)
    end

    it 'should return 404 when no mrk found' do
      request_data_for_mrk_issue[:xliff_trans_unit_mrk][:data][:id] = -1
      get get_by_mrk_api_job_webta_issues_path(cms_request.id), request_data_for_mrk_issue, headers_with_token
      error_response = JSON.parse(response.body)
      expect(error_response['code']).to eq(404)
      expect(error_response['message']).to eq('XliffTransUnitMrk with id: -1 not found')
    end

    it 'should return 404 when no source mrk found' do
      request_data_for_mrk_issue[:xliff_trans_unit_mrk][:data][:mrk_type] = XliffTransUnitMrk::MRK_TYPES[:source].to_s
      get get_by_mrk_api_job_webta_issues_path(cms_request.id), request_data_for_mrk_issue, headers_with_token
      error_response = JSON.parse(response.body)
      expect(error_response['code']).to eq(404)
      expect(error_response['message']).to eq("Source XliffTransUnitMrk with id: #{xliff_trans_unit_mrk.id} not found")
    end

    it 'should return issues for the target mrk when no mrk_type is passed' do
      # create issue by invoking create API
      post create_issue_by_mrk_api_job_webta_issues_path(cms_request), valid_json_with_mrk, headers_with_token
      issue = Issue.last

      # fetch issues for particular mrk
      request_data_for_mrk_issue[:xliff_trans_unit_mrk][:data][:mrk_type] = nil
      get get_by_mrk_api_job_webta_issues_path(cms_request.id), request_data_for_mrk_issue, headers_with_token
      issue_json = JSON.parse(response.body).first
      expect(issue_json['data']['id']).to eq(issue.id)
      expect(issue_json['data']['attributes']['subject']).to eq(issue.title)
      expect(issue_json['data']['attributes']['message']).to eq(issue.messages.first.body)
    end

    it 'should return issues for the source mrk' do
      # create issue for target mrk by invoking create API
      post create_issue_by_mrk_api_job_webta_issues_path(cms_request), valid_json_with_mrk, headers_with_token
      issue_for_target_mrk = Issue.last

      # create issue for source mrk by invoking create API
      xliff_trans_unit_mrk.update_attributes!(source_id: xliff_trans_unit_mrk_source_type.id)
      request_data_with_mrk[:mrk][:id] = xliff_trans_unit_mrk.id
      request_data_with_mrk[:mrk][:mrk_type] = XliffTransUnitMrk::MRK_TYPES[:source].to_s
      post create_issue_by_mrk_api_job_webta_issues_path(cms_request), request_data_with_mrk.to_json, headers_with_token
      issue_for_source_mrk = Issue.last

      # fetch issues for particular mrk
      request_data_for_mrk_issue[:xliff_trans_unit_mrk][:data][:id] = xliff_trans_unit_mrk.id
      request_data_for_mrk_issue[:xliff_trans_unit_mrk][:data][:mrk_type] = XliffTransUnitMrk::MRK_TYPES[:source].to_s
      get get_by_mrk_api_job_webta_issues_path(cms_request.id), request_data_for_mrk_issue, headers_with_token
      issue_json = JSON.parse(response.body).first
      expect(issue_json['data']['id']).to eq(issue_for_source_mrk.id)
      expect(issue_json['data']['attributes']['subject']).to eq(issue_for_source_mrk.title)
      expect(issue_json['data']['attributes']['message']).to eq(issue_for_source_mrk.messages.first.body)
    end

    it 'should return issue counts for client and translator of each mrk' do
      # create two issues for translator
      post create_issue_by_mrk_api_job_webta_issues_path(cms_request), valid_json_with_mrk, headers_with_token
      post create_issue_by_mrk_api_job_webta_issues_path(cms_request), valid_json_with_mrk, headers_with_token

      # create one issue for client
      request_data_with_mrk[:issue][:target_type] = 'client'
      post create_issue_by_mrk_api_job_webta_issues_path(cms_request), request_data_with_mrk.to_json, headers_with_token

      get api_job_webta_issues_path(cms_request.id), {}, headers_with_token
      mrk_id = xliff_trans_unit_mrk.id.to_s

      expect(response).to have_http_status(200)
      json = JSON.parse(response.body)
      expect(json.keys.first).to eq(mrk_id)
      expect(json[mrk_id]['for_client']).to eq(1)
      expect(json[mrk_id]['for_translator']).to eq(2)
    end

    it 'should return 404 when invalid cms_request_id is passed' do
      get api_job_webta_issues_path(-1), {}, headers_with_token
      expect(response).to have_http_status 404
    end
  end

  context 'POST create_issue_by_mrk' do
    it 'should not create issue for mrk with invaild authentication' do
      cms = @cms
      post create_issue_by_mrk_api_job_webta_issues_path(cms), {}, @headers_with_reviewer.merge('Authorization' => 'invaild')
      error_response = JSON.parse(response.body)
      expect(error_response['error']).to eq('Not Authorized')
    end

    it 'should not allow to create issue for user other than translator and reviewer' do
      cms = @cms
      another_translator = FactoryGirl.create(:beta_translator, capacity: 100)
      token = auth_token(another_translator)
      post create_issue_by_mrk_api_job_webta_issues_path(cms), {}, @headers_with_reviewer.merge('Authorization' => token)
      expect(response.code).to eq('404')
      expect(response.message).to eq('Not Found')
    end

    it 'should not create issue for mrk with invaild xliff_id' do
      cms = @cms
      invalid_params = @valid_params.deep_dup
      invalid_params[:xliff_id] = -1
      post create_issue_by_mrk_api_job_webta_issues_path(cms), invalid_params.to_json, @headers_with_reviewer
      error_response = JSON.parse(response.body)
      expect(error_response['code']).to eq(409)
      expect(error_response['message']).to eq('Not matching mrk with xliff')
    end

    it 'should return 404 when no source mrk found' do
      cms = @cms
      mrk = FactoryGirl.create(:xliff_trans_unit_mrk, mrk_type: XliffTransUnitMrk::MRK_TYPES[:target], cms_request: @cms)
      invalid_params = @valid_params.deep_dup
      invalid_params[:mrk][:id] = mrk.id
      invalid_params[:mrk][:mrk_type] = XliffTransUnitMrk::MRK_TYPES[:source].to_s
      post create_issue_by_mrk_api_job_webta_issues_path(cms, @issue), invalid_params.to_json, @headers_with_reviewer
      error_response = JSON.parse(response.body)
      expect(error_response['code']).to eq(404)
      expect(error_response['message']).to eq("Source XliffTransUnitMrk with id: #{invalid_params[:mrk][:id]} not found")
    end

    it 'should create new issue by reviewer for mrk' do
      cms = @cms
      post create_issue_by_mrk_api_job_webta_issues_path(cms), @valid_params.to_json, @headers_with_reviewer
      issue = Issue.last
      json_response = JSON.parse(response.body)
      expect(issue.id).to eq(json_response['data']['id'])
      expect(issue.owner.id).to eq(@valid_params[:mrk][:id])
      expect(issue.initiator).to eq(@reviewer)
      expect(issue.kind).to eq(@valid_params[:issue][:kind].constantize)
      expect(issue.title).to eq(cms.title + ' issue #1')
      expect(issue.target.id).to eq(@translator.id)

      # Validating issue title
      post create_issue_by_mrk_api_job_webta_issues_path(cms), @valid_params.to_json, @headers_with_reviewer
      issue2 = Issue.last
      expect(issue2.title).to eq(cms.title + ' issue #2')

      # Validating issue title
      post create_issue_by_mrk_api_job_webta_issues_path(cms), @valid_params.to_json, @headers_with_reviewer
      issue3 = Issue.last
      expect(issue3.title).to eq(cms.title + ' issue #3')
    end

    it 'should create new issue with target as client when target_type as client is passed' do
      cms = @cms
      invalid_params = @valid_params.deep_dup
      invalid_params[:issue][:target_type] = 'client'
      client = @cms.website.client
      post create_issue_by_mrk_api_job_webta_issues_path(cms), invalid_params.to_json, @headers_with_reviewer
      issue = Issue.last
      json_response = JSON.parse(response.body)
      expect(issue.target).to eq(client)
    end

    it 'should create new issue with target as client when no target_type is passed' do
      cms = @cms
      invalid_params = @valid_params.deep_dup
      invalid_params[:issue][:target_type] = nil
      client = @cms.website.client
      post create_issue_by_mrk_api_job_webta_issues_path(cms), invalid_params.to_json, @headers_with_reviewer
      issue = Issue.last
      expect(issue.target).to eq(client)
    end

    it 'should create new issue with kind as ISSUE_GENERAL_QUESTION when no issue kind is passed' do
      cms = @cms
      invalid_params = @valid_params.deep_dup
      invalid_params[:issue][:kind] = nil
      post create_issue_by_mrk_api_job_webta_issues_path(cms), invalid_params.to_json, @headers_with_reviewer
      issue = Issue.last
      expect(issue.kind).to eq(ISSUE_GENERAL_QUESTION)
    end

    it 'should return 400 when invalid issue kind is passed' do
      cms = @cms
      invalid_params = @valid_params.deep_dup
      invalid_params[:issue][:kind] = 'INVALID_ISSUE_KIND'
      post create_issue_by_mrk_api_job_webta_issues_path(cms), invalid_params.to_json, @headers_with_reviewer
      issue = Issue.last
      error_response = JSON.parse(response.body)
      expect(error_response['code']).to eq(400)
      expect(error_response['message']).to eq('Issue kind is invalid')
    end

    it 'should return error when invalid mrk_id is passed' do
      cms = @cms
      invalid_params = @valid_params.deep_dup
      invalid_params[:mrk][:id] = -1
      post create_issue_by_mrk_api_job_webta_issues_path(cms), invalid_params.to_json, @headers_with_reviewer
      error_response = JSON.parse(response.body)
      expect(error_response['code']).to eq(404)
      expect(error_response['message']).to eq('XliffTransUnitMrk with ID: -1 was not found')
    end
  end

  context 'POST close_issue' do
    before(:each) do
      @cms = FactoryGirl.create_list(:cms_request, 1, :with_dependencies).first
      @cms.cms_target_language.update_attribute(:translator, @translator)
      @xliff_trans_unit_mrk = FactoryGirl.create(:xliff_trans_unit_mrk, cms_request: @cms)
      @issue = FactoryGirl.create(:issue, owner: @xliff_trans_unit_mrk, target: @translator, title: 'This is a title for issue', kind: ISSUE_INCORRECT_TRANSLATION, status: ISSUE_OPEN)
      message = FactoryGirl.create(:message, owner: @issue, body: 'This is a message body')
    end

    it 'should return 404 when issue not found' do
      post close_issue_api_job_webta_issue_path(@cms, -1), {}.to_json, @headers
      error_response = JSON.parse(response.body)
      expect(error_response['code']).to eq(404)
      expect(error_response['message']).to eq('Issue with ID: -1 was not found')
    end

    it 'should return 400 when issue does not have at least one reply' do
      post close_issue_api_job_webta_issue_path(@cms, @issue), {}.to_json, @headers
      error_response = JSON.parse(response.body)
      expect(error_response['code']).to eq(400)
      expect(error_response['message']).to eq('Issue does not have reply messages')
    end

    context 'when translator created the issue' do
      before do
        @issue.update_attributes(initiator_id: @translator.id)
      end

      it 'should return 200 when issue does not have at least one reply' do
        post close_issue_api_job_webta_issue_path(@cms, @issue), {}.to_json, @headers
        json = JSON.parse(response.body)

        expect(response.code).to eq '200'
        expect(json['data']['id']).to eq(@issue.id)
        expect(json['data']['attributes']['status']).to eq('Issue closed')
        expect(json['data']['attributes']['message']).to eq('This is a message body')
      end
    end

    it 'should close the issue' do
      message2 = FactoryGirl.create(:message, owner: @issue, body: 'This is a message2 body')
      post close_issue_api_job_webta_issue_path(@cms, @issue), {}.to_json, @headers
      json = JSON.parse(response.body)
      expect(json['data']['id']).to eq(@issue.id)
      expect(json['data']['attributes']['status']).to eq('Issue closed')
      expect(json['data']['attributes']['message']).to eq('This is a message body')
    end

    it 'should not allow to update issue when user is neither translator nor reviewer for the job' do
      other_user = FactoryGirl.create(:beta_translator)
      token = auth_token(other_user)
      post close_issue_api_job_webta_issue_path(@cms, @issue), {}.to_json, @headers.merge('Authorization' => token)
      expect(response.code).to eq('404')
      expect(response.message).to eq('Not Found')
    end
  end

  context 'POST create_issue_message' do
    before(:each) do
      @cms = FactoryGirl.create_list(:cms_request, 1, :with_dependencies).first
      @cms.cms_target_language.update_attribute(:translator, @translator)
      @xliff_trans_unit_mrk = FactoryGirl.create(:xliff_trans_unit_mrk, cms_request: @cms)
      @issue = FactoryGirl.create(:issue, owner: @xliff_trans_unit_mrk, target: @translator, title: 'This is a title for issue', kind: ISSUE_INCORRECT_TRANSLATION, status: ISSUE_OPEN)
      message = FactoryGirl.create(:message, owner: @issue, body: 'This is a message body')
    end

    it 'should create new message for the issue' do
      message_params = {
        issue_id: @issue.id,
        message: {
          body: 'This is a message body for issue'
        }
      }
      post create_issue_message_api_job_webta_issue_path(@cms, @issue), message_params.to_json, @headers
      json = JSON.parse(response.body)
      expect(json['data']['body']).to eq(message_params[:message][:body])
    end

    it 'should return 404 when issue not found' do
      post create_issue_message_api_job_webta_issue_path(@cms, 0), {}, @headers
      error_response = JSON.parse(response.body)
      expect(error_response['code']).to eq(404)
      expect(error_response['message']).to eq('Issue with ID: 0 was not found')
    end

    it 'should return 400 when no message params is passed' do
      post create_issue_message_api_job_webta_issue_path(@cms, @issue), {}, @headers
      error_response = JSON.parse(response.body)
      expect(error_response['code']).to eq(400)
      expect(error_response['message']).to eq('Message body is not present')
    end

    it 'should not allow to create issue message when user is neither translator nor reviewer for the job' do
      other_user = FactoryGirl.create(:beta_translator)
      token = auth_token(other_user)
      post create_issue_message_api_job_webta_issue_path(@cms, @issue), {}, @headers.merge('Authorization' => token)
      expect(response.code).to eq('404')
      expect(response.message).to eq('Not Found')
    end
  end

end
