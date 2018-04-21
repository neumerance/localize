require 'rails_helper'
require 'support/utils_helper'

RSpec.describe 'CmsRequests', type: :request do
  include Rack::Test::Methods
  include ActionDispatch::TestProcess
  include UtilsHelper

  let!(:client) { FactoryGirl.create(:client) }
  let!(:translator) { FactoryGirl.create(:translator) }
  let!(:beta_translator) { FactoryGirl.create(:beta_translator) }
  let!(:website) { FactoryGirl.create(:website, client_id: client.id) }
  let!(:source_language) { FactoryGirl.find_or_create(:language, name: 'English') }
  let!(:target_language) { FactoryGirl.find_or_create(:language, name: 'German') }
  let!(:offer) { FactoryGirl.create(:website_translation_offer, website_id: website.id, from_language_id: source_language.id, to_language_id: target_language.id, status: 2) }
  let!(:contract) { FactoryGirl.create(:website_translation_contract, website_translation_offer_id: offer.id, translator_id: translator.id, status: 2) }

  let!(:request_data) do
    {
      api_version: '1.0',
      project_id: website.id,
      accesskey: website.accesskey,
      job: {
        id: 1,
        file: Rack::Test::UploadedFile.new("#{Rails.root}/spec/fixtures/files/xliffs/test-en-fr.xliff.gz", 'application/gzip', true),
        title: 'Title from job',
        note: 'MyText',
        translator_id: translator.id,
        cms_id: 'job_cms_id',
        word_count: 1,
        url: 'some-url-here',
        source_language: 'English',
        target_language: 'German',
        deadline: 1498733437
      }
    }

  end

  let!(:valid_json) do
    # request_data.to_json
  end

  let!(:headers) { { 'CONTENT_TYPE' => 'application/json', 'ACCEPT' => 'application/json' } }

  describe 'POST create' do

    it 'should should save deadline' do
      cms_count = CmsRequest.count
      post website_cms_requests_path(website.id, format: :json), request_data, headers
      expect(CmsRequest.count).to eq(cms_count + 1)
      cms = CmsRequest.last
      expect(cms.title).to eq(request_data[:job][:title])
      expect(cms.note).to eq(request_data[:job][:note])
      expect(cms.permlink).to eq(request_data[:job][:url])
      expect(cms.deadline.to_i).to eq(request_data[:job][:deadline])
    end

    it 'should work withoud deadline' do
      request_data_without_deadline = request_data.except(:job)
      request_data_without_deadline[:job] = request_data[:job].except(:deadline)
      puts request_data_without_deadline
      cms_count = CmsRequest.count
      post website_cms_requests_path(website.id, format: :json), request_data_without_deadline, headers
      expect(CmsRequest.count).to eq(cms_count + 1)
      cms = CmsRequest.last
      expect(cms.title).to eq(request_data[:job][:title])
      expect(cms.note).to eq(request_data[:job][:note])
      expect(cms.permlink).to eq(request_data[:job][:url])
      expect(cms.deadline).to be_nil
    end
  end

end
