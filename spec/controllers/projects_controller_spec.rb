require 'spec_helper'
require 'rails_helper'
require 'support/utils_helper'

RSpec.describe ProjectsController, type: :controller do
  include UtilsHelper

  let(:client) do
    client = FactoryGirl.create(:client)
    FactoryGirl.create_list(:revision, 3, cms_request_id: nil, client: client)
    client
  end

  before(:each) do
    @original_per_page_summary = PER_PAGE_SUMMARY
    Kernel.silence_warnings { PER_PAGE_SUMMARY = 2 }
    login_as(client)
  end

  after(:each) do
    Kernel.silence_warnings { PER_PAGE_SUMMARY = @original_per_page_summary }
  end

  describe 'GET #searcher' do
    describe 'pagination' do
      context 'as an admin user' do
        it 'displays the correct number of records in the first page' do
          get :searcher,
              xhr: true,
              params: { format: :js, page: 1 }
          expect(assigns(:projects).length).to eq(2)
        end

        it 'displays the correct number of records in the second page' do
          get :searcher,
              xhr: true,
              params: { format: :js, page: 2 }
          expect(assigns(:projects).length).to eq(1)
        end
      end
    end
  end
end
