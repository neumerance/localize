require 'spec_helper'
require 'rails_helper'
require 'support/utils_helper'

describe WebMessagesController, type: :controller do
  include ActionDispatch::TestProcess
  include UtilsHelper
  render_views

  let!(:client) { FactoryGirl.create(:client) }
  let!(:translator) { FactoryGirl.create(:translator) }
  let!(:web_message) { FactoryGirl.create(:web_message, owner: client) }
  let!(:admin) { FactoryGirl.create(:admin) }

  context 'as translator' do
    before do
      web_message.translator = translator
      web_message.translation_status = TRANSLATION_IN_PROGRESS
      web_message.save

      login_as(translator)
    end

    describe 'GET edit' do
      context 'when timeout expired' do
        it 'should redirect to index' do
          web_message.translate_time = 1.day.ago

          get :edit, params: { id: web_message.id }
          expect(response).to redirect_to(action: :index)
        end

        it 'should redirect if job is not in progress' do
          web_message.translation_status = 4
          get :edit, params: { id: web_message.id }
          expect(response).to redirect_to(action: :index)
        end

      end
    end

    describe 'GET index' do
      it 'should not contain errors' do
        get :index
        expect(response).to have_http_status 200
      end

      context 'when translator has a web message in progress' do
        before do
          web_message.translator = translator
          web_message.translation_status = TRANSLATION_IN_PROGRESS
          web_message.translate_time = Time.now
          web_message.save

          get :index
        end

        it 'should assign the current web_message' do
          expect(assigns(:current_message)).to eq(web_message)
        end
        it 'should show a button to continue translation' do
          expect(response.body).to include('Continue translating')
        end

        it 'should not show web messages table' do
          expect(response).not_to include('The following Instant Translation projects are available for you:')
        end
      end
    end

    describe 'POST hold_for_translation' do
      before do
        web_message.money_account = build(:money_account, balance: 100)
      end
      it 'should redirect when translation is in progress' do
        another_web_message = create(:web_message)
        post :hold_for_translation, id: another_web_message.id

        expect(response).to redirect_to(web_messages_path)
      end
    end

    describe 'PATCH #update' do
      def calculate_md5(string)
        Digest::MD5.hexdigest(string)
      end

      let!(:web_message) { FactoryGirl.create(:web_message) }
      let(:plain_text_string) { 'Foo bar baz.' }
      let(:encoded_once) { Base64.encode64(plain_text_string) }
      let(:encoded_three_times) { Base64.encode64(Base64.encode64(encoded_once)) }

      it 'decodes the body' do
        patch :update,
              params: { id: web_message.id,
                        body: encoded_once,
                        body_md5: calculate_md5(encoded_once) }
        web_message.reload
        expect(web_message.visitor_body).to eq(plain_text_string)
      end

      # A bug in the desktop TAS causes the body and/or title to sometimes be
      # encoded twice or more times.
      it 'decodes the body if encoded three times' do
        patch :update,
              params: { id: web_message.id,
                        body: encoded_three_times,
                        body_md5: calculate_md5(encoded_three_times) }
        web_message.reload
        expect(web_message.visitor_body).to eq(plain_text_string)
      end

      context do
        let(:encoded) do
          'VElFTkkgTEEgVFVBDQpGQU1JR0xJQSBBTCBTSUNVUk8NCg0KTE9DQUxJWlpBDQpMQSBUVUEgDQpGQU1JR0xJQQ0KRSBHTEkgQU1JQ0kNCg0KR1VBUkRBIExBIExPUk8NCkNST05PTE9HSUENCkRJIFZJQUdHSU8NCg0KUklDRVZJDQpOT1RJRklDSEUNClNVTExBIExPUk8NClBPU0laSU9ORQ0KDQpDT05ESVZJREkNCkxBIFRVQQ0KUE9TSVpJT05FDQoNCkFHR0lVTkdJDQpMVU9HSEkNClBFUlNPTkFMSVpaQVRJDQoNCkNSRUENCkUgR0VTVElTQ0kNCkRJVkVSU0kNCkdSVVBQSQ=='
        end

        let(:text) { Base64.decode64(encoded) }

        it do
          patch :update,
                params: { id: web_message.id,
                          body: encoded,
                          body_md5: calculate_md5(encoded) }

          expect(response).to be_success
          web_message.reload
          expect(web_message.visitor_body).to eq(text)
        end
      end
    end
  end

  context 'as admin' do
    describe 'GET review_index' do
      it 'should redirect to home' do
        login_as(admin)
        get :review_index
        expect(response).to redirect_to(controller: :supporter, action: :index)

      end
    end
  end
end
