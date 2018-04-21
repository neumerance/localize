require 'spec_helper'
require 'rails_helper'
require 'support/utils_helper'

RSpec.describe 'Glossaries', type: :request do
  include UtilsHelper

  before(:all) do
    @translator = FactoryGirl.create(:beta_translator, capacity: 100)
    @reviewer = FactoryGirl.create(:beta_translator, capacity: 100)
    @cms_request = FactoryGirl.create_list(:cms_request, 1, :with_dependencies).first
    @cms_request.revision.chats.each { |chat| chat.update_attribute(:translator, @translator) }
    @source_language = Language.find_by_name('English')
    @target_language = Language.find_by_name('French')
    @cms_request.cms_target_language.update_attributes(translator: @translator, language: @target_language)
    @cms_request.revision.revision_languages.last.managed_work.update_attributes(translator: @reviewer)
    @glossary_term = FactoryGirl.create(:glossary_term, txt: 'Test phrase in english', description: 'Description for test phrase in english', language: @source_language, client: @cms_request.website.client)
    @glossary_translation = FactoryGirl.create(:glossary_translation, glossary_term: @glossary_term, txt: 'Translated test phrase in French', language: @target_language)

    @token = auth_token(@translator)
    @headers = { 'CONTENT_TYPE' => 'application/json', 'ACCEPT' => 'application/json', 'Authorization' => @token }

    @reviewer_token = auth_token(@reviewer)
    @reviewer_headers = { 'CONTENT_TYPE' => 'application/json', 'ACCEPT' => 'application/json', 'Authorization' => @reviewer_token }
  end

  describe 'GET index' do
    it 'should return glossaries along with translations for translator' do
      get api_glossaries_path, { cms_request_id: @cms_request.id }, @headers
      json = ActiveSupport::JSON.decode(response.body)
      expect(json.count).to eq 1

      json = json.first
      expect(json['id']).to eq(@glossary_term.id)
      expect(json['term']).to eq('Test phrase in english')
      expect(json['description']).to eq('Description for test phrase in english')
      expect(json['original_language']).to eq('English')
      expect(json['translated_text']).to eq('Translated test phrase in French')
      expect(json['translation_language']).to eq('French')
    end

    it 'should return glossaries along with translations for reviewer' do
      get api_glossaries_path, { cms_request_id: @cms_request.id }, @reviewer_headers
      json = ActiveSupport::JSON.decode(response.body)
      expect(json.count).to eq 1

      json = json.first
      expect(json['id']).to eq(@glossary_term.id)
      expect(json['term']).to eq('Test phrase in english')
      expect(json['description']).to eq('Description for test phrase in english')
      expect(json['original_language']).to eq('English')
      expect(json['translated_text']).to eq('Translated test phrase in French')
      expect(json['translation_language']).to eq('French')
    end

    it 'should allow only translator or reviewer to get list of glossaries' do
      another_user = FactoryGirl.create(:beta_translator, capacity: 100)
      token = auth_token(another_user)
      get api_glossaries_path, { cms_request_id: @cms_request.id }, @headers.merge('Authorization' => token)
      expect(response.code).to eq('404')
      expect(response.message).to eq('Not Found')
    end

    it 'should not allow unauthorized user to get list of glossaries' do
      get api_glossaries_path, { cms_request_id: @cms_request.id }, @headers.merge('Authorization' => 'unauthorized')
      expect(response.code).to eq('401')
      expect(response.message).to eq('Unauthorized')
    end
  end

  describe 'POST create' do
    before(:each) do
      @glossary_params = {
        cms_request_id: @cms_request.id,
        term: 'Tit for tat',
        description: 'Do same with the person what he does with others.',
        translated_text: 'Tit pour tat'
      }
    end

    it 'should create glossaries by translator' do
      post api_glossaries_path, @glossary_params.to_json, @headers
      json = ActiveSupport::JSON.decode(response.body)

      expect(json['id']).to eq(GlossaryTerm.last.id)
      expect(json['original_language']).to eq('English')
      expect(json['term']).to eq('Tit for tat')
      expect(json['description']).to eq('Do same with the person what he does with others.')
      expect(json['translation_language']).to eq('French')
      expect(json['translated_text']).to eq('Tit pour tat')
    end

    it 'should create glossaries by reviewer' do
      post api_glossaries_path, @glossary_params.to_json, @reviewer_headers
      json = ActiveSupport::JSON.decode(response.body)

      expect(json['id']).to eq(GlossaryTerm.last.id)
      expect(json['original_language']).to eq('English')
      expect(json['term']).to eq('Tit for tat')
      expect(json['description']).to eq('Do same with the person what he does with others.')
      expect(json['translation_language']).to eq('French')
      expect(json['translated_text']).to eq('Tit pour tat')
    end

    it 'should raise 400 when blank glossary term is passed' do
      @glossary_params[:term] = ''
      post api_glossaries_path, @glossary_params.to_json, @headers
      error_response = JSON.parse(response.body)
      expect(error_response['code']).to eq(400)
      expect(error_response['message']).to eq('Glossary term can not be blank')
    end

    it 'should raise 400 when blank description for the term is passed' do
      @glossary_params[:description] = ''
      post api_glossaries_path, @glossary_params.to_json, @headers
      error_response = JSON.parse(response.body)
      expect(error_response['code']).to eq(400)
      expect(error_response['message']).to eq('Description can not be blank')
    end

    it 'should raise 400 when blank translated text for the term is passed' do
      @glossary_params[:translated_text] = ''
      post api_glossaries_path, @glossary_params.to_json, @headers
      error_response = JSON.parse(response.body)
      expect(error_response['code']).to eq(400)
      expect(error_response['message']).to eq('Translated text can not be blank')
    end

    it 'should allow only translator or reviewer to create glossaries' do
      another_user = FactoryGirl.create(:beta_translator, capacity: 100)
      token = auth_token(another_user)
      post api_glossaries_path, @glossary_params.to_json, @headers.merge('Authorization' => token)
      expect(response.code).to eq('404')
      expect(response.message).to eq('Not Found')
    end

    it 'should not allow unauthorized user to create glossaries' do
      post api_glossaries_path, @glossary_params.to_json, @headers.merge('Authorization' => 'unauthorized')
      expect(response.code).to eq('401')
      expect(response.message).to eq('Unauthorized')
    end
  end

  describe 'PUT update' do
    before(:each) do
      @glossary_params = {
        cms_request_id: @cms_request.id,
        description: 'Nice term description',
        target_language_id: 1,
        translation: 'Some translation'
      }
    end

    it 'should update existing GlossaryTerm and GlossaryTranslation' do
      put api_glossary_path(@glossary_term.id), @glossary_params.to_json, @headers
      json = ActiveSupport::JSON.decode(response.body)
      expect(response.code).to eq('200')
      expect(json['code']).to eq(200)
      @glossary_term.reload
      glossary_translation = @glossary_term.glossary_translations.where(language_id: @glossary_params[:target_language_id]).last
      expect(@glossary_term.description).to eq(@glossary_params[:description])
      expect(glossary_translation.txt).to eq(@glossary_params[:translation])
      expect(glossary_translation.last_editor_id).to eq(@translator.id)
      expect(glossary_translation.creator_id).to eq(@translator.id)
    end

    it 'should respond with 404 for wrong cms_request' do
      @glossary_params[:cms_request_id] = FactoryGirl.create(:cms_request).id
      put api_glossary_path(@glossary_term.id), @glossary_params.to_json, @headers
      expect(response).to have_http_status(404)
    end

  end
end
