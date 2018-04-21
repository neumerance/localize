require 'spec_helper'
require 'rails_helper'
require 'support/utils_helper'

describe ToolsController, type: :controller do
  include ActionDispatch::TestProcess
  include UtilsHelper
  render_views

  describe 'POST create_resource_from_po' do
    let(:params) do
      {
        resource_upload: fixture_file_upload('files/all_formats/1_normal_java.java', 'plain/text'),
        po_upload: fixture_file_upload('files/all_formats/4_normal_po.po', 'plain/text'),
        outout_encoding: 1,
        delimiter: 1,
        line_end: 1,
        commit: 'Create the translated Java resource file »'
      }
    end

    context 'when no files are provided' do
      it 'should redirect and set flash message' do
        post :create_resource_from_po, params: params.except(:resource_upload)
        expect(flash[:notice]).to include('You must select both PO and resource files to scan')
        expect(response).to redirect_to(action: :java_resource_reconstructor)
      end
    end

    context 'when invalid files are provided' do
      it 'should redirect and set flash message' do
        new_params = params.clone
        new_params[:po_upload] = { uploaded_data: fixture_file_upload('files/test.xliff.gz') }
        post :create_resource_from_po, params: params.except(:resource_upload)
        expect(flash[:notice]).to include('You must select both PO and resource files to scan')
        expect(response).to redirect_to(action: :java_resource_reconstructor)
      end
    end

    context 'when valid files' do
      let(:params) do
        {
          php_upload: fixture_file_upload('files/завантаження.php', 'application/zip'),
          commit: 'Create the translated Java resource file »'
        }
      end

      before do
        allow(controller).to receive(:extract_gettext_code) do
          ['Завантаження', '(カタカナ or 片仮名)'].map { |l| l.force_encoding('ASCII-8BIT') }
        end
      end

      it do
        post :create_po_from_php, params: params
        puts response.body
      end
    end
  end
end
