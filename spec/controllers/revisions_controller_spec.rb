require 'spec_helper'
require 'rails_helper'
require 'support/utils_helper'

RSpec.describe RevisionsController, type: :controller do
  include UtilsHelper

  describe 'GET #select_private_translators' do
    let(:client) { FactoryGirl.create(:client) }
    let(:admin) { FactoryGirl.create(:admin) }
    let(:revision) do
      project = FactoryGirl.create(:project, client: client)
      FactoryGirl.create(:revision, project: project)
    end

    context 'as an admin (supporter)' do
      before(:each) do
        login_as(admin)
        get :select_private_translators,
            params: { project_id: revision.project_id, id: revision.id }
      end

      it 'does not allow access (redirects)' do
        expect(response).to have_http_status(:redirect)
      end

      it 'sets an "access denied" flash message' do
        expect(flash[:notice]).to eq('Only clients can access this page.')
      end
    end

    context 'as a client' do
      before(:each) do
        login_as(client)
        get :select_private_translators,
            params: { project_id: revision.project_id, id: revision.id }
      end

      it 'allows access (returns HTTP status code 200)' do
        expect(response).to have_http_status(:success)
      end

      it 'does not set a flash message' do
        expect(flash).to be_blank
      end
    end
  end
end
