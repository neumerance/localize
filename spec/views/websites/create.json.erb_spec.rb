require 'rails_helper'

describe 'websites/create' do
  fixtures :websites
  before(:all) { @template = 'websites/create.json.erb' }

  context 'when parameters are correct' do
    before(:each) { assign(:website, websites(:amir_wp)) }

    it_should_behave_like 'json success'

    it 'return project id' do
      render template: 'websites/create.json.erb'
      json_resp = JSON.parse(response.body)
      expect(json_resp).to include('project')
      expect(json_resp['project']).to include('id')
    end

    it 'return project accesskey' do
      render template: 'websites/create.json.erb'
      json_resp = JSON.parse(response.body)
      expect(json_resp).to include('project')
      expect(json_resp['project']).to include('accesskey')
    end
  end
end
