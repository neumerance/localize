# I found a lot of expectation of these  expect(response).to have_http_status(:success)
# which is wrong because if a website is not created, the controller is raising an exception
# which lead to have_http_status(:error)
# so i just removed it because an assertion is in placed to check if website is created.

require 'rails_helper'

describe WebsitesController, type: :controller do

  include ActiveSupport::Testing::Assertions
  fixtures :users, :websites

  describe 'test_validate_affiliate' do
    let(:user) { users(:shark) }

    # test with wrong values
    context 'when wrong parameters' do
      it 'returns ERROR' do
        get(:validate_affiliate, params: { format: 'xml', affiliate_id: user.id, affiliate_key: user.affiliate_key + 'x' })
        expect(response).to have_http_status(:success)
        expect(assigns(:result)).to eq('ERROR')
      end
    end

    context 'when correct parameters' do
      it 'returns OK' do
        get(:validate_affiliate, params: { format: 'xml', affiliate_id: user.id, affiliate_key: user.affiliate_key })
        expect(response).to have_http_status(:success)
        expect(assigns(:result)).to eq('OK')
      end
    end
  end

  describe 'GET custom_text' do
    let(:verb) { :get }
    let(:action) { :show }
    let(:use_website_id) { false }
    let(:website) { websites(:amir_wp) }
    let :custom_text_params do
      {
        api_version: '1.0',
        format: :json,
        id: website.id,
        project_id: website.id,
        accesskey: website.accesskey,
        location: 'dashboard'
      }
    end

    it_should_behave_like 'require website id and accesskey'

    context 'with valid id an key' do
      context 'with location dashboard' do
        it 'founds a website' do
          get(:custom_text, params: custom_text_params, 'HTTP_ACCEPT' => 'application/json')
          expect(assigns(:website)).to eq(website)
        end
        %w(account_total planned_expenses balance).each do |assign|
          it "set #{assign}" do
            get(:custom_text, params: custom_text_params, 'HTTP_ACCEPT' => 'application/json')
            expect(assigns(assign)).to be
          end
        end
      end

      context 'with location translators' do
        it 'founds a website' do
          params = custom_text_params
          params[:location] = 'translators'
          get(:custom_text, params: params, 'HTTP_ACCEPT' => 'application/json')
          expect(assigns(:website)).to eq(website)
        end
      end

      context 'with location string_translation' do
        it 'founds a website' do
          params = custom_text_params
          params[:location] = 'string_translation'
          get(:custom_text, params: params, 'HTTP_ACCEPT' => 'application/json')
          expect(assigns(:website)).to eq(website)
        end
      end

      context 'with location reminders' do
        before(:each) do
          params = custom_text_params
          params[:location] = 'reminders'
          get(:custom_text, params: params, 'HTTP_ACCEPT' => 'application/json')
        end
        it('founds a website') { expect(assigns(:website)).to eq(website) }
        it('have reminders') { expect(assigns(:reminders)).to be }
      end

      context 'with unexisting location' do
        it 'returns invalid params' do
          params = custom_text_params
          params[:location] = 'foo'
          get(:custom_text, params: params, 'HTTP_ACCEPT' => 'application/json')
          expect(assigns(:json_code)).to eq(INVALID_PARAMS)
        end
      end
    end
  end

  describe 'GET website' do
    let(:verb) { :get }
    let(:action) { :show }
    let(:website) { websites(:amir_wp) }
    let(:use_website_id) { false }
    it_should_behave_like 'require website id and accesskey'

    let :get_website_params do
      {
        format: :json,
        id: website.id,
        project_id: website.id,
        accesskey: website.accesskey
      }
    end

    describe 'with correct parameters' do
      it 'find the website' do
        get(:show, params: get_website_params, 'HTTP_ACCEPT' => 'application/json')
        expect(assigns(:website)).to eq(website)
      end
    end
  end

  describe 'POST create' do
    before(:each) { @request.env['HTTP_ACCEPT'] = 'application/json' }
    before(:each) { allow(RestClient).to receive(:post) { json_success_string } }
    let :post_website_params do
      {
        api_version: '1.0',
        project: {
          blogid: 123,
          url: 'http://testblog.com',
          name: 'test blog',
          description: 'this is a blog used on tests',
          delivery_method: 'xmlrpc'
        }
      }
    end

    context 'when parameters are correct' do
      it 'need website parameters' do
        assert_difference 'Website.count', 1 do
          post(:create, params: post_website_params, 'HTTP_ACCEPT' => 'application/json')
        end
      end

      [:blogid, :url, :name, :description].each do |attr|
        it "have the correct #{attr}" do
          post(:create, params: post_website_params)
          expect(Website.last.send(attr)).to eq(post_website_params[:project][attr])
        end
      end

      it 'have the correct api version' do
        post(:create, params: post_website_params)
        expect(Website.last.api_version).to eq('1.0')
      end

    end

    context 'when it have one affiliate' do
      let(:affiliate) { users(:amir) }

      describe 'with correct params' do
        let(:current_params) do
          params = post_website_params
          params[:affiliate] = { id: affiliate.id, key: affiliate.affiliate_key }
          params
        end

        it 'set correctly the affiliate' do
          post(:create, params: current_params)
          expect(Website.last.client.affiliate).to eq(affiliate)
        end
      end

      context 'with incorrect affiliate params' do
        let(:current_params) do
          params = post_website_params
          params[:affiliate] = { id: affiliate.id, key: 'foobar' }
          params
        end

        it 'affiliate is nil' do
          post(:create, params: current_params)
          expect(Website.last.client.affiliate).to be_nil
        end
      end
    end

    context 'when parameters are not correct' do
      let(:invalid_params) do
        params = post_website_params
        params[:project].delete(:name)
        params.delete(:format)
      end

      before(:each) do
        post(:create, params: invalid_params, 'HTTP_ACCEPT' => 'application/json')
      end

      it 'does not create a website' do
        assert_no_difference 'Website.count' do
          post(:create, params: invalid_params)
        end
      end

      it 'return the correct custom error code' do
        expect(assigns(:json_code)).to eq(WEBSITE_NOT_CREATED)
      end

      it 'returns a 422 HTTP status code' do
        expect(response).to have_http_status(422)
      end

      it 'returns the validation error in the response body' do
        expect(response.body).to include('can\'t be blank')
      end
    end

  end

  describe 'POST migrate' do
    let(:website) { Website.first }

    context 'when everything is okay' do
      it 'sets migrated_to_tp to 1' do
        xhr :post, :migrate, params: { format: 'json', project_id: website.id, id: website.id, accesskey: website.accesskey }, headers: { 'Content-Type' => 'application/json', 'Accept' => 'application/json' }
        expect(website.reload.migrated_to_tp).to eq(1)
      end
      it 'sets pickup_type to PICKUP_BY_POLLING' do
        xhr :post, :migrate, params: { format: 'json', project_id: website.id, id: website.id, accesskey: website.accesskey }, headers: { 'Content-Type' => 'application/json', 'Accept' => 'application/json' }
        expect(website.reload.pickup_type).to eq(PICKUP_BY_POLLING)
      end
      it 'sets api_version to 1.0' do
        xhr :post, :migrate, params: { format: 'json', project_id: website.id, id: website.id, accesskey: website.accesskey }, headers: { 'Content-Type' => 'application/json', 'Accept' => 'application/json' }
        expect(website.reload.api_version).to eq('1.0')
      end
    end
    context 'when there is an error' do
      it 'does not update the website if request format is different than JSON' do
        xhr :post, :migrate, params: { project_id: website.id, id: website.id, accesskey: website.accesskey }, headers: { 'Content-Type' => 'application/json', 'Accept' => 'application/json' }
        expect(website.reload.migrated_to_tp).to eq(0)
      end
    end
  end

  describe '#create_by_cms' do

    let :valid_parameters do
      { 'create_account' => '1',
        'anon' => '1',
        'platform_kind' => '2',
        'cms_kind' => '1',
        'blogid' => '1',
        'url' => 'http://www.koeoep.com',
        'title' => 'Professional UAV Drone Supplier',
        'description' => '',
        'is_verified' => '1',
        'interview_translators' => '1',
        'project_kind' => '2',
        'pickup_type' => '0',
        'notifications' => '0',
        'ignore_languages' => '0',
        'from_language1' => 'English',
        'to_language1' => 'Chinese ',
        'debug_cms' => 'WordPress',
        'debug_module' => 'WPML 3.1.5',
        'debug_url' => 'http://www.koeoep.com',
        'format' => 'xml' }
    end

    context 'with valid parameters' do
      it 'should not raise double render' do
        post :create_by_cms, params: valid_parameters
        expect(response).to have_http_status(200)
      end

      it 'creates a unique nickname and email for each anonymous account' do
        # Fix icldev-487 which made impossible to create more than one
        # account in the same minute as their generated email and nickname
        # would be the same, causing a validation error.
        post :create_by_cms, params: valid_parameters
        expect(response).to have_http_status(:success)
        post :create_by_cms, params: valid_parameters
        expect(response).to have_http_status(:success)
      end
    end

    context 'with invalid parameters' do
      it 'should not raise double render' do
        post :create_by_cms, format: :xml
        expect(response).to have_http_status(422)
      end
    end
  end

  describe '#translator_chat' do
    let!(:cms_request) { FactoryGirl.create(:cms_request, :with_dependencies) }
    let(:website) { cms_request.website }
    let(:translator) { website.cms_requests.first.translator }
    let(:translation_contract) { website.website_translation_contracts.first }
    let(:translation_offer) { translation_contract.website_translation_offer }

    context 'given a valid translator_id' do
      it 'Redirects to the expected translation contract URL' do
        valid_params = {
          # This parameter's name is misleading. It expects a website ID,
          # not a Project ID (e.g., cms_request.revision.project.id)
          project_id: website.id,
          accesskey: website.accesskey,
          translator_id: translator.id,
          compact: 1,
          lc: 'en',
          id: website.id
        }

        expected_url =
          website_website_translation_offer_website_translation_contract_url(
            website, translation_offer, translation_contract, compact: 1
          )

        get :translator_chat, params: valid_params
        expect(response).to redirect_to(expected_url)
      end
    end

    context 'given an invalid translator_id' do
      it 'Displays an error flash message and redirects to the client index' do
        incorrect_translator = FactoryGirl.create(:translator)

        valid_params = {
          # This parameter's name is misleading. It expects a website ID,
          # not a Project ID (e.g., cms_request.revision.project.id)
          project_id: website.id,
          accesskey: website.accesskey,
          translator_id: incorrect_translator.id,
          compact: 1,
          lc: 'en',
          id: website.id
        }

        get :translator_chat, params: valid_params
        expect(flash[:notice]).to include('translator is not')
        expect(response).to redirect_to('/client?compact=1')
      end
    end
  end

end
