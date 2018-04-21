require 'spec_helper'
require 'rails_helper'
require 'support/utils_helper'

RSpec.describe SearchController, type: :controller do
  include UtilsHelper
  describe 'GET by_language' do
    let!(:admin) { FactoryGirl.create(:admin) }
    context 'with Admin' do
      it 'should return 200' do
        login_as(admin)
        get :by_language, params: { go_back: 1, source_lang_id: 1, target_lang_id: 3 }
        expect(response.status).to be 200
      end
    end
  end
end
