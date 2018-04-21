require 'spec_helper'
require 'rails_helper'
require 'support/utils_helper'

RSpec.describe 'Client Projects Report', type: :request do
  include UtilsHelper

  let(:supporter) { FactoryGirl.create(:supporter, password: '123456') }
  before(:each) { request_spec_login(supporter.email, '123456') }

  # ReportsController#clients_projects
  describe 'GET /reports/clients_projects' do
    before(:each) do
      get '/reports/clients_projects', params: { commit: 'Export to CSV' }
    end
    let(:response_lines_count) { response.body.split("\n").size }

    # It is currently not possible to match all report contents to a csv fixture
    # file or a string due to differences in the local test DBs of the
    # developers and the CI server's test DB.

    context 'with CSV format' do
      it 'returns HTTP status code 200' do
        expect(response).to have_http_status(200)
      end

      it 'returns the correct content type' do
        expect(response.content_type).to eq 'text/plain'
      end

      it 'has the correct column count' do
        comma_count = response.body.count(',')
        expect(comma_count / response_lines_count).to eq(11)
      end
    end
  end
end
