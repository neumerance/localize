require 'spec_helper'
require 'rails_helper'
require 'support/utils_helper'

describe ResourceDownloadsController, type: :controller do
  include ActionDispatch::TestProcess
  include UtilsHelper
  render_views

  describe 'GET download' do
    let!(:client) { create(:client) }
    let!(:text_resource) { create(:text_resource, client: client, language_id: 1) }
    let!(:resource_download) { create(:resource_download, text_resource: text_resource) }

    before do
      allow_any_instance_of(ResourceDownload).to receive(:get_contents) { 'Testing' }
      login_as(client)
    end

    it 'calls get contents and orig_filename on ResourceDownload' do
      expect_any_instance_of(ResourceDownload).to receive(:get_contents).once
      expect_any_instance_of(ResourceDownload).to receive(:orig_filename).once
      get :download, params: { id: resource_download.id, text_resource_id: text_resource.id }
    end

    it 'has a valid response' do
      get :download, params: { id: resource_download.id, text_resource_id: text_resource.id }
      expect(response.body).to eq('Testing')
      expect(response.code).to eq('200')
    end

    it "redirect if user can't view project" do
      allow_any_instance_of(Client).to receive(:can_view?) { false }
      get :download, params: { id: resource_download.id, text_resource_id: text_resource.id }
      expect(response.code).to eq('302')
    end
  end

end
