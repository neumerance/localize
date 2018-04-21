
require 'spec_helper'
require 'rails_helper'

describe Api::V1::GlossariesController, type: :controller do

  include ActionDispatch::TestProcess

  let!(:headers) { { 'CONTENT_TYPE' => 'application/json', 'ACCEPT' => 'application/json' } }
  let!(:client) { FactoryGirl.create(:client) }
  let!(:translator) { FactoryGirl.create(:translator, password: '123', beta_user: true) }
  let!(:website) { FactoryGirl.create(:website, client: client) }
  let!(:cms) { FactoryGirl.create_list(:cms_request, 1, :with_dependencies).first }
  let!(:cms_target_language) { FactoryGirl.create(:cms_target_language, cms_request: cms) }
  let!(:glossary_term) { FactoryGirl.create(:glossary_term, client: client, language: cms.language) }
  let!(:glossary_translation) { FactoryGirl.create(:glossary_translation, glossary_term: glossary_term, language: cms.cms_target_language.language) }

  context 'glossary' do
    it 'should return results' do
      cms.update_attributes!(website: website)
      cms.revision.revision_languages.last.managed_work.update_attributes(translator: translator)
      SESSION_TOKEN = JsonWebToken.encode(user_id: translator.id)
      @request.headers['Authorization'] = SESSION_TOKEN
      get :index, params: { cms_request_id: cms.id, format: :json }
      expect(response).to have_http_status(200)
      expect(JSON.parse(response.body).length).to be > 0
    end
  end

end
