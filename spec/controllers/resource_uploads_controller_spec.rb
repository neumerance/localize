require 'spec_helper'
require 'rails_helper'
require 'support/utils_helper'

describe ResourceUploadsController, type: :controller do
  include ActionDispatch::TestProcess
  include UtilsHelper
  render_views

  fixtures :resource_formats

  before do
    login_as(client)
  end

  let!(:client) { create(:client) }
  let!(:resource_format) { build(:resource_format) }
  let!(:text_resource) { create(:text_resource, client: client, language_id: 1, resource_format: resource_format) }

  describe 'POST create ' do
    let(:params) do
      {
        resource_upload: {
          uploaded_data: fixture_file_upload('files/sample_utf8.txt', 'application/octet-stream')
        },
        resource_format_id: resource_format.id,
        text_resource_id: text_resource.id
      }
    end
    context 'rescue from errors parsing the file' do
      it 'set flash message if file contains emojis' do
        tester_string = 'Im an error that should appear in flash'
        allow_any_instance_of(ResourceFormat).to receive(:extract_texts).and_raise Parsers::ParseError.new(tester_string)
        post :create, params: params
        expect(flash[:problem]).to eq(tester_string)
      end

      it 'set flash message if there is a parse error' do
        allow_any_instance_of(ResourceFormat).to receive(:extract_texts).and_raise Parsers::EmojisNotSupported
        post :create, params: params
        expect(flash[:problem]).to include('contains emojis')
      end
    end

    Dir[Rails.root.join('spec/fixtures/files/all_formats/*')].each do |filename|
      it "should process file #{File.basename(filename)}" do
        file = fixture_file_upload("files/all_formats/#{File.basename(filename)}", 'application/octet-stream')
        resource_format_id = filename.match(/\d+/).to_s || raise("File not valid for resource_upload testing: #{filename}")
        post :create, params: {
          resource_upload: {
            uploaded_data: file
          },
          resource_format_id: resource_format_id,
          text_resource_id: text_resource.id
        }

        if filename.include? 'emoji'
          expect(flash[:problem]).to include('contains emojis')
        else
          expect(response.status).to eq(200)
        end
      end
    end
  end

  describe 'POST scan_resource' do
    let!(:resource_upload) { create(:resource_upload, text_resource: text_resource) }

    context 'when is rescued form ActiveRecord::StatementInvalid when invalid chars are uploaded' do
      before do
        allow_any_instance_of(ResourceFormat).to receive(:extract_texts).and_return(
          [
            {
              token: 'abc',
              text: 'And 🙋 Raise your hand!',
              translation: '',
              comments: nil
            }
          ]
        )
        # @ToDO Factory is not settings this correctly.
        resource_upload.set_contents 'key=value'
      end

      def make_request
        post(:scan_resource, params: {
               text_resource_id: text_resource.id,
               string_token: { Digest::MD5.hexdigest('abc') => 1 },
               id: resource_upload.id
             })
      end

      it 'should redirect to index' do
        make_request
        expect(response).to redirect_to(text_resource_path(text_resource, anchor: :upload_new))
      end
      it 'should set a flash[problem]' do
        make_request
        expect(flash[:problem]).to be_present
      end
      it 'should call Parsers.logger' do
        expect(Parsers).to receive(:logger)
        make_request
      end
    end
  end

end
