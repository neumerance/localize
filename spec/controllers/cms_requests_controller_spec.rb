require 'rails_helper'

describe CmsRequestsController, type: :controller do

  render_views

  include ActionDispatch::TestProcess
  include ActiveSupport::Testing::Assertions
  fixtures :cms_requests, :users, :websites, :website_translation_contracts, :cms_target_languages

  describe 'POST notify_cms_delivery' do
    let(:verb) { :post }
    let(:action) { :notify_cms_delivery }
    let(:use_website_id) { true }
    let(:cms_request) { cms_request = cms_requests(:page1); cms_request.update_attribute :status, CMS_REQUEST_TRANSLATED; cms_request }
    let(:website) { cms_request.website }
    let(:valid_params) do
      {
        id: cms_request.id,
        format: :json,
        website_id: cms_request.website.id,
        project_id: cms_request.website.id,
        accesskey: cms_request.website.accesskey
      }
    end

    it 'sets status to CMS_REQUEST_DONE' do
      post :notify_cms_delivery, params: valid_params, headers: { 'HTTP_ACCEPT' => 'application/json' }
      cms_request.reload
      expect(cms_request.status).to eq(CMS_REQUEST_DONE)
      expect(cms_request.completed_at).not_to be nil
    end
  end

  describe 'POST deliver' do
    let(:verb) { :post }
    let(:action) { :deliver }
    let!(:website) { FactoryGirl.create(:website) }
    # let!(:cms_request) do
    #   cms_request = cms_requests(:page1)
    #   cms_request.website = website
    #   cms_request.save!
    #   cms_request.xliffs << Xliff.create!(uploaded_data: fixture_file_upload('files/test.xliff', 'text/plain'))
    #   cms_request
    # end
    let!(:cms_request) { FactoryGirl.create(:cms_request, :with_dependencies) }
    let!(:xliff) { FactoryGirl.create(:xliff, cms_request: cms_request, uploaded_data: TempContent.new("#{Rails.root}/spec/fixtures/files/test.xliff")) }
    let(:session) { TasComm.new.create_session_for_user(cms_request.website.client) }
    let(:valid_params) do
      {
        format: :xml,
        website_id: cms_request.website.id,
        id: cms_request.id,
        file: fixture_file_upload('files/test.xliff.gz', 'text/plain')
      }
    end
    before(:each) { allow(TranslationProxy::Notification).to receive(:deliver) { true } }

    describe 'with valid params' do
      it 'Adds a new xliff on cms_request' do
        assert_difference 'cms_request.reload.xliffs.count', 1 do
          post :deliver, params: valid_params.merge(session: session), headers: { 'HTTP_ACCEPT' => 'application/json' }
        end
      end
      it 'Send file to translation proxy' do
        expect(TranslationProxy::Notification).to receive(:deliver)
        post :deliver, params: valid_params.merge(session: session)
      end
      it "Don't generate an error" do
        post :deliver, params: valid_params.merge(session: session), headers: { 'HTTP_ACCEPT' => 'application/json' }
        expect(assigns(:err_code)).to be nil
      end
    end

    describe 'with missing file' do
      let(:current_params) do
        ret = valid_params
        ret.delete(:file)
        ret
      end
      it 'should set error to -1' do
        post :deliver, params: current_params.merge(session: session), headers: { 'HTTP_ACCEPT' => 'application/json' }
        expect(assigns(:err_code)).to eq(-1)
      end
      it 'should set the correct error message' do
        post :deliver, params: current_params.merge(session: session), headers: { 'HTTP_ACCEPT' => 'application/json' }
        expect(assigns(:status)).to match(/Missing file/)
      end
    end

    describe 'with no session' do
      it 'should set error to -1' do
        post :deliver, xhr: true, params: valid_params, headers: { 'HTTP_ACCEPT' => 'application/json' }
        expect(assigns(:err_code)).to eq(NOT_LOGGED_IN_ERROR)
      end
      it 'should set the correct error message' do
        post :deliver, xhr: true, params: valid_params, headers: { 'HTTP_ACCEPT' => 'application/json' }
        expect(assigns(:status)).to match(/logging in/)
      end
    end
  end

  describe 'GET download' do
    before(:each) do
    end

    let(:cms_request) do
      cms_request = cms_requests(:page1)
      cms_request.xliffs << Xliff.create!(uploaded_data: fixture_file_upload('files/test.xliff', 'text/plain'), translated: true)
      cms_request
    end

    let(:valid_params) do
      {
        format: :json,
        project_id: cms_request.website.id,
        accesskey: cms_request.website.accesskey,
        job: {
          id: cms_request.id
        }
      }
    end

    describe 'with existing translation' do
      before(:each) do
        get :download, params: valid_params, headers: { 'HTTP_ACCEPT' => 'application/json' }
      end

      it('is an file') { expect(response.headers['Content-Type']).to eq('application/octet-stream') }
      it('have an attachment') { expect(response.headers['Content-Disposition']).to eq('attachment; filename="test.xliff"') }
    end

    describe 'with unexistent xliff' do
      let(:cms_request) { cms_requests(:post1) }
      let(:current_params) do
        {
          format: :json,
          project_id: cms_request.website.id,
          accesskey: cms_request.website.accesskey,
          job: {
            id: cms_request.id
          }
        }
      end

      before(:each) do
        get :download, params: current_params, headers: { 'HTTP_ACCEPT' => 'application/json' }
      end

      it('have no attachment') { expect(response.headers['Content-Disposition']).to be_blank }
      it('returns error') do
        expect(assigns(:json_code)).to eq(XLIFF_NOT_TRANSLATED)
      end
    end

    describe "when cms_request don't exists" do
      let(:current_params) do
        {
          format: :json,
          project_id: cms_request.website.id,
          accesskey: cms_request.website.accesskey,
          job: {
            id: cms_request.id + 1_000_000
          }
        }
      end

      before(:each) do
        get :download, params: current_params, headers: { 'HTTP_ACCEPT' => 'application/json' }
      end

      it('have no attachment') { expect(response.headers['Content-Disposition']).to be_blank }
      it('returns error') do
        expect(assigns(:json_code)).to eq(CMS_REQUEST_NOT_FOUND)
      end
    end
  end

  describe 'GET xliff' do
    let!(:cms_request) { FactoryGirl.create(:cms_request, :with_dependencies) }
    let!(:xliff) { FactoryGirl.create(:xliff, cms_request: cms_request, uploaded_data: TempContent.new("#{Rails.root}/spec/fixtures/files/test.xliff")) }
    let(:session) { TasComm.new.create_session_for_user(cms_request.website.client) }

    let(:valid_params) do
      {
        format: :xml,
        website_id: cms_request.website.id,
        id: cms_request.id
      }
    end

    describe 'with existing xliff' do
      before(:each) do
        get :xliff, params: valid_params.merge(session: session), headers: { 'HTTP_ACCEPT' => 'application/json' }
      end

      it('is an file') { expect(response.headers['Content-Type']).to eq('application/octet-stream') }
      it('have an attachment') { expect(response.headers['Content-Disposition']).to eq('attachment; filename="test.xliff"') }
    end

    describe 'with unexistent xliff' do
      let(:cms_request) { cms_requests(:post1) }
      let(:current_params) do
        {
          format: :xml,
          website_id: cms_request.website.id,
          id: cms_request.id,
          version: :translated
        }
      end

      before(:each) do
        get :xliff, params: current_params.merge(session: session), headers: { 'HTTP_ACCEPT' => 'application/json' }
      end

      it('have no attachment') do
        expect(response.headers['Content-Disposition']).to be_blank
      end
      it('returns error') do
        expect(assigns(:err_code)).to eq(-1)
      end
    end

    describe 'with no permission' do
      let(:session) { TasComm.new.create_session_for_user(users(:orit)) }

      it 'raises an exception which Rails rescues and responds with 404' do
        expect do
          get :xliff, params: valid_params.merge(session: session), headers: { 'HTTP_ACCEPT' => 'application/json' }
        end.to raise_exception(ActionController::RoutingError, 'Not Found')
      end
    end
  end

  describe 'POST create' do
    before(:each) do
      # Hack for any_instance mock in rspec 1.x
      allow(TasComm).to receive(:new) { TasComm }
      allow(TasComm).to receive(:create_project) { true }
    end
    let(:verb) { :post }
    let(:action) { :create }
    let(:use_website_id) { true }
    let(:website) { websites(:amir_wp) }
    let(:translator) { website.website_translation_contracts.first.translator }
    let(:source_language) { website.website_translation_contracts.first.website_translation_offer.from_language }
    let(:target_language) { website.website_translation_contracts.first.website_translation_offer.to_language }
    it_should_behave_like 'require website id and accesskey'

    let(:valid_params) do
      {
        api_version: 1.0,
        format: :json,
        website_id: website.id,
        project_id: website.id,
        accesskey: website.accesskey,
        job: {
          id: 123,
          file: fixture_file_upload('files/test.xliff', 'text/plain'),
          title: 'FAQ',
          cms_id: 'page_123_en_sp',
          word_count: 100,
          url: 'http://blog.com',
          translator_id: translator.id, # optional
          note: 'Translate these words', # optional
          source_language: source_language.name,
          target_language: target_language.name
        }
      }
    end

    shared_examples_for 'do not create the objects' do
      it "doesn't create the cms request" do
        assert_no_difference('CmsRequest.count') { post(:create, params: current_params, 'HTTP_ACCEPT' => 'application/json') }
      end
      it "doesn't create the cms target language" do
        assert_no_difference('CmsTargetLanguage.count') { post(:create, params: current_params, 'HTTP_ACCEPT' => 'application/json') }
      end
      it "doesn't create the xliff file" do
        assert_no_difference('Xliff.count') { post(:create, params: current_params, 'HTTP_ACCEPT' => 'application/json') }
      end
    end

    shared_examples_for 'create the objects' do
      it 'create the cms request' do
        assert_difference('CmsRequest.count', 1) { post(:create, params: current_params, 'HTTP_ACCEPT' => 'application/json') }
      end
      it 'create the cms target language' do
        assert_difference('CmsTargetLanguage.count', 1) { post(:create, params: current_params, 'HTTP_ACCEPT' => 'application/json') }
      end
      it 'create a xliff' do
        assert_difference('Xliff.count', 1) { post(:create, params: current_params, 'HTTP_ACCEPT' => 'application/json') }
      end
    end

    describe 'with correct params' do
      let(:current_params) { valid_params }
      it_should_behave_like 'create the objects'

      describe 'cms request attributes' do
        before(:each) { post(:create, params: valid_params, 'HTTP_ACCEPT' => 'application/json') }
        it('set correctly website_id') { expect(CmsRequest.last.website_id).to eq(website.id) }
        it('set correctly permlink') { expect(CmsRequest.last.permlink).to eq('http://blog.com') }
        it('set correctly cms_id') { expect(CmsRequest.last.cms_id).to eq('page_123_en_sp') }
        it('set correctly word_count') { expect(CmsRequest.last.word_count).to eq(100) }
        it('set correctly the source language') { expect(CmsRequest.last.language.id).to eq(source_language.id) }
        it('set correctly the note') { expect(CmsRequest.last.note).to eq('Translate these words') }
        it('set correctly the status') { expect(CmsRequest.last.status).to eq(CMS_REQUEST_WAITING_FOR_PROJECT_CREATION) }
        it('set correctly the notified') { expect(CmsRequest.last.notified).to eq(0) }
        it('set correctly the tp_id') { expect(CmsRequest.last.tp_id).to eq(123) }
        it('set correctly the tp_id') { expect(CmsRequest.last.title).to eq('FAQ') }
        it('have a cms target language') { expect(CmsRequest.last.cms_target_languages.first).to be }
      end

      describe 'cms target language attributes' do
        before(:each) { post(:create, params: valid_params, 'HTTP_ACCEPT' => 'application/json') }
        it('set correctly the status') { expect(CmsTargetLanguage.last.status).to eq(CMS_TARGET_LANGUAGE_CREATED) }
        it('set correctly the translator') { expect(CmsTargetLanguage.last.translator.id).to eq(translator.id) }
        it('set correctly the target language') { expect(CmsTargetLanguage.last.language.id).to eq(target_language.id) }
        it('set correctly the cms request') { expect(CmsTargetLanguage.last.cms_request.id).to eq(CmsRequest.last.id) }
      end

      describe 'xliff attributes' do
        before(:each) { post(:create, params: valid_params, 'HTTP_ACCEPT' => 'application/json') }
        it('set correctly the website') { expect(Xliff.last.cms_request.id).to eq(CmsRequest.last.id) }
        it('is not translated') { expect(Xliff.last.translated?).to be false }
      end
    end

    describe 'with missing job params' do
      [:id, :file, :source_language, :target_language, :translator_id, :cms_id, :url, :title].each do |attr|
        let(:current_params) do
          ret = valid_params
          ret[:job].delete(attr)
          ret
        end
        it_should_behave_like 'do not create the objects'
        it_should_behave_like 'invalid params error'
      end
    end

    describe 'with unexistent source or target language' do
      [:source_language, :target_language].each do |attr|
        let(:current_params) do
          ret = valid_params
          ret[:job][attr] = 'unexistent language'
          ret
        end
        it_should_behave_like 'do not create the objects'
        it 'sets json_code to language not found' do
          post(:create, params: current_params, 'HTTP_ACCEPT' => 'application/json')
          expect(assigns(:json_code)).to eq(LANGUAGE_NOT_FOUND)
        end
      end
    end

    describe 'with no translator' do
      let(:current_params) do
        ret = valid_params
        ret[:job].delete(:translator_id)
        ret
      end
      it_should_behave_like 'create the objects'
      it 'sets the transltor to null on cms target language' do
        post(:create, params: current_params, 'HTTP_ACCEPT' => 'application/json')
        expect(CmsTargetLanguage.last.translator).to be nil
      end
    end

    describe 'when creating 2 jobs for the same WP page' do
      def get_cms_request_id_from_json
        JSON.parse(response.body).with_indifferent_access[:response][:job][:id]
      end

      let(:do_request) do
        lambda do |extra_params|
          post(:create, params: valid_params.deep_merge(extra_params), 'HTTP_ACCEPT' => 'application/json')
        end
      end

      context 'when each request has a different tp_id' do
        it 'should create a separate CmsRequest for each API call' do
          do_request.call({})
          expect { do_request.call(job: { id: 12 }) }.to change { get_cms_request_id_from_json }
        end
      end

      context 'when TP resends a create request with the same tp_id' do
        it 'should reuse the same CmsRequest for all API calls' do
          expect do
            do_request.call({})
          end.to change(CmsRequest, :count).by(1)

          expect do
            expect { do_request.call({}) }.not_to change { get_cms_request_id_from_json }
          end.not_to change(CmsRequest, :count)
        end
      end

      context 'when blocking involved' do
        let(:second_controller) do
          CmsRequestsController.new
        end

        it do
          do_request.call({})
          expect(controller.cms_request.base_xliff.parsed_xliff).to be
        end

        def add_cms_dependencies(cms)
          FactoryGirl.create(:revision,
                             cms_request: cms,
                             client: cms.website.client,
                             project: cms.website.client.projects.first)
          FactoryGirl.create(:revision_language, revision: cms.revision) unless cms.revision.revision_language
          FactoryGirl.create(:chat, revision: cms.revision)
          FactoryGirl.create(:bid, :won, :accepted, :with_bid_account,
                             revision_language: cms.revision.revision_languages.last,
                             chat: cms.revision.chats.last)
          FactoryGirl.create(:managed_work,
                             :waiting_for_payment,
                             owner_id: cms.revision.revision_languages.last.id,
                             owner_type: 'RevisionLanguage',
                             client_id: cms.website.client.id)
        end

        context 'without blocking jobs' do
          context 'when cancelable' do
            it do
              do_request.call({})
              first_cms = controller.cms_request
              expect(first_cms.base_xliff.parsed_xliff).to be

              second_controller.params = controller.params
              second_controller.params[:job][:id] = 124

              second_cms = CmsRequestsController::Create.new(second_controller, first_cms.website).call
              expect(second_cms.base_xliff.parsed_xliff).to be
            end
          end

          context 'when completed' do
            it do
              do_request.call({})
              first_cms = controller.cms_request
              expect(first_cms.base_xliff.parsed_xliff).to be
              first_cms.update_attributes(status: CMS_REQUEST_DONE)

              second_controller.params = controller.params
              second_controller.params[:job][:id] = 124

              second_cms = CmsRequestsController::Create.new(second_controller, first_cms.website).call
              expect(second_cms.base_xliff.parsed_xliff).to be
            end
          end
        end

        context 'with blocking jobs' do
          context 'when in progress (non-cancellable)' do
            context 'with review disabled' do
              it 'waits for first job to complete before processing second job' do
                do_request.call({})
                first_cms = controller.cms_request
                expect(first_cms.base_xliff.parsed_xliff).to be
                first_cms.update_attributes(status: CMS_REQUEST_RELEASED_TO_TRANSLATORS)
                first_cms.cms_target_language.update_attributes(status: CMS_TARGET_LANGUAGE_ASSIGNED)
                add_cms_dependencies(first_cms)

                second_controller.params = controller.params
                second_controller.params[:job][:id] = 124

                second_cms = CmsRequestsController::Create.new(second_controller, first_cms.website).call
                expect(second_cms.base_xliff.parsed_xliff).to be_nil

                first_cms.reload.complete!
                expect(second_cms.reload.base_xliff.parsed_xliff).to be
              end
            end

            context 'with review enabled' do
              it 'cancels the review and refunds the client' do
                # Create first cms_request
                do_request.call({})
                first_cms = controller.cms_request
                expect(first_cms.base_xliff.parsed_xliff).to be

                first_cms.update(review_enabled: true)

                # Simulates a translator taking the job (e.g.
                # CmsRequestsController#assign_to_me) so it's "in progress".
                first_cms.update_attributes(status: CMS_REQUEST_RELEASED_TO_TRANSLATORS)
                first_cms.cms_target_language.update_attributes(status: CMS_TARGET_LANGUAGE_ASSIGNED)
                add_cms_dependencies(first_cms)

                # Set the cost of the job
                first_cms.cms_target_language.update(word_count: 100)
                bid = first_cms.revision.revision_language.selected_bid
                bid.update(amount: 0.1)
                wtc = first_cms.website_translation_offer.website_translation_contracts.where(translator: translator).first
                wtc.update(amount: 0.1)
                # 100 words * $0.10 per word = $10, plus 50% for the review.
                expect(first_cms.calculate_required_balance[0]).to eq 15.0
                bid.account.update(balance: 15.0)
                client_account = first_cms.website.client.money_account
                client_account.update(balance: 0)

                # Create second cms_request for the same WP page
                second_controller.params = controller.params
                second_controller.params[:job][:id] = 124

                second_cms = CmsRequestsController::Create.new(second_controller, first_cms.website).call
                expect(second_cms.base_xliff.parsed_xliff).to be_nil

                # Cancels review for the first job
                expect(first_cms.reload.review_enabled).to be false
                expect(first_cms.revision.revision_language.managed_work.active).to be 0
                # Refunds refund the review amount to the client
                expect(bid.account.reload.balance).to eq 10.0
                expect(client_account.reload.balance).to eq 5.0

                first_cms.reload.complete!
                expect(second_cms.reload.base_xliff.parsed_xliff).to be
              end
            end
          end
        end
      end
    end

    describe 'with a tp_id already created' do
      it 'should not create a new cms request' do
        # create the first one
        post(:create, params: valid_params, 'HTTP_ACCEPT' => 'application/json')
        assert_no_difference('CmsRequest.count') { post(:create, params: valid_params, 'HTTP_ACCEPT' => 'application/json') }
      end

      context 'when TP retries multiple times' do
        it 'should create only one cms_request' do
          count = CmsRequest.count
          5.times do
            post(:create, params: valid_params, 'HTTP_ACCEPT' => 'application/json')
          end

          expect(CmsRequest.count).to eq(count + 1)
        end
      end
    end
  end

  describe '#index' do
    describe 'XML request' do
      let(:website) { Website.first }
      context 'when filter includes pending_TAS' do
        it 'returns a list of filtered cms_requests' do
          get :index, params: { website_id: website.id, filter: 'pending_TAS', format: 'xml', accesskey: website.accesskey }, headers: { 'Content-Type' => 'application/xml', 'Accept' => 'application/xml' }
          expect(assigns(:cms_requests).count).to eq(1)
        end
      end
      context 'when filter includes sent' do
        it 'returns a list of filtered cms_requests' do
          get :index, params: { website_id: website.id, filter: 'sent', format: 'xml', accesskey: website.accesskey }, headers: { 'Content-Type' => 'application/xml', 'Accept' => 'application/xml' }
          expect(assigns(:cms_requests).count).to eq(12)
        end
      end
      context 'when filter includes pickup' do
        it 'returns a list of filtered cms_requests' do
          get :index, params: { website_id: website.id, filter: 'pickup', format: 'xml', accesskey: website.accesskey }, headers: { 'Content-Type' => 'application/xml', 'Accept' => 'application/xml' }
          expect(assigns(:cms_requests).count).to eq(1)
        end
      end
      context 'when request contains container param' do
        it 'returns a list of filtered cms_requests' do
          get :index, params: { website_id: website.id, container: 'example_container', format: 'xml', accesskey: website.accesskey }, headers: { 'Content-Type' => 'application/xml', 'Accept' => 'application/xml' }
          expect(assigns(:cms_requests).count).to eq(2)
        end
      end
      context 'when request contains show_languages param' do
        it 'returns a list of filtered cms_requests' do
          get :index, params: { website_id: website.id, show_languages: 'true', format: 'xml', accesskey: website.accesskey }, headers: { 'Content-Type' => 'application/xml', 'Accept' => 'application/xml' }
          parsed_results = Nokogiri::XML(response.body)
          expect(parsed_results.xpath('//target_language').count).to eq(3)
        end
      end
      context 'when request does not contain any additional format params' do
        it 'returns an unfiltered list of cms_request' do
          get :index, params: { website_id: website.id, format: 'xml', accesskey: website.accesskey }, headers: { 'Content-Type' => 'application/xml', 'Accept' => 'application/xml' }
          expect(assigns(:cms_requests).count).to eq(14)
        end
      end
    end
  end

  describe '#assign_to_me' do
    include UtilsHelper

    let!(:translator) { FactoryGirl.create(:translator) }
    let!(:cms_request) { FactoryGirl.create(:cms_request, :with_dependencies) }
    let(:cms_target_language) { cms_request.cms_target_language }
    let(:website) { cms_request.website }
    let(:website_translation_contract) { website.website_translation_contracts.first }
    let(:website_translation_offer) { website.website_translation_offers.first }
    let(:translator) { cms_target_language.translator }
    let(:client) { website.client }
    let!(:money_account) do
      client.create_default_money_account
      client.money_account
    end

    let(:valid_params) do
      {
        cms_target_language: { cms_target_language.id => 1 },
        commit: 'Start translating',
        website_id: cms_request.website_id,
        id: cms_request.id
      }
    end

    # Do *not* use bang (let!) here as we only want this record to be created
    # for some tests.
    let(:pending_money_transaction) do
      PendingMoneyTransaction.reserve_money_for_cms_requests([cms_request])
    end

    before(:each) do
      cms_target_language.update!(
        translator: nil,
        status: 0,
        word_count: 100,
        language: website_translation_offer.to_language
      )
      website_translation_offer.disable_automatic_translator_assignment!
      website_translation_contract.update(
        amount: 0.09,
        status: TRANSLATION_CONTRACT_ACCEPTED,
        translator: translator
      )
      money_account.update(balance: 9.0)
      login_as(translator)
    end

    describe 'require money to be reserved' do
      context 'with reserved money' do
        before(:each) do
          # Trigger the lazy creation of a pending_money_transaction
          pending_money_transaction
          post :assign_to_me, params: valid_params
        end

        it 'responds with 200 status' do
          expect(response).to have_http_status(:success)
        end

        it 'assigns the translator' do
          expect(cms_target_language.reload.translator).to eq translator
        end
      end

      context 'without reserved money' do
        before(:each) { post :assign_to_me, params: valid_params }

        it 'responds with 302 (redirect) status' do
          expect(response).to have_http_status(:redirect)
        end

        it 'sets a flash message' do
          expect(flash[:notice]).to include('not paid')
        end

        it 'does not assign the translator' do
          expect(cms_target_language.reload.translator).to be_nil
        end
      end
    end
  end
end
