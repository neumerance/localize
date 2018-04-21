require 'spec_helper'
require 'rails_helper'
require 'support/utils_helper'

describe UsersController, type: :controller do
  include ActionDispatch::TestProcess
  include UtilsHelper

  let!(:admin) { FactoryGirl.create(:admin) }
  let!(:client) { FactoryGirl.create(:client) }
  let!(:translator) { FactoryGirl.create(:translator) }
  let!(:other_translator) { FactoryGirl.create(:translator) }

  context 'supporter logged in' do

    it 'should be able to set webta access for translator' do
      login_as(admin)
      translator = FactoryGirl.create(:translator)
      expect(translator.webta_enabled?).to be_falsey
      post :webta_access, params: { id: translator.id, format: :js }
      expect(translator.reload.webta_enabled?).to be_truthy
      post :webta_access, params: { id: translator.id, format: :js }
      expect(translator.reload.webta_enabled?).to be_falsey
    end

  end

  context 'register' do
    let!(:valid_client) do
      {
        utype: 'Client',
        auser: {
          next_operation: '',
          source: '',
          fname: 'Valid',
          lname: 'Client',
          email: 'Valid.Client@icanlocalize.com',
          nickname: 'validclient',
          password: '123456',
          phone_country: '',
          phone_number: ''
        },
        accept_agreement: '1',
        submit: 'Sign Up'
      }
    end

    it 'should be able to register as client' do
      code, cid = captcha_code
      client_count = Client.count
      post :create, params: valid_client.merge(code: code, captcha_id: cid)
      expect(response).to have_http_status(200)
      expect(Client.count).to eq(client_count + 1)
    end

    it 'should downcase email of client' do
      code, cid = captcha_code
      client_count = Client.count
      post :create, params: valid_client.merge(code: code, captcha_id: cid)
      user = assigns(:auser)
      expect(user.email).to eq(valid_client[:auser][:email].downcase)
    end

  end

  context 'search' do

    let!(:client) { FactoryGirl.create(:client, email: 'SoMeEmAiL@ICanLocaliZe.CoM', password: '123456') }
    let!(:a_client) { FactoryGirl.create(:client, fname: 'A\'lMaHoNnee', lname: 'O\'Connror') }

    it 'should be able to find it with any capitalization on index page' do
      login_as(admin)
      post :index, params: { keyword: randomize_case(client.email) }
      expect(response).to have_http_status(200)
      expect(assigns(:users_page).map(&:id).include?(client.id)).to be_truthy
    end

    it 'should be able to find it with any capitalization on find_results page' do
      login_as(admin)
      post :find_results, params: { keywords: { fname: randomize_case(client.fname), lname: randomize_case(client.lname), email: randomize_case(client.email), nickname: randomize_case(client.nickname) } }
      expect(response).to have_http_status(200)
      expect(assigns(:users_page).map(&:id).include?(client.id)).to be_truthy
    end

    it 'should be able to find it with names containing apostrophes on find_results page' do
      login_as(admin)
      post :find_results, params: { keywords: { fname: a_client.fname, lname: a_client.lname, email: a_client.email, nickname: a_client.nickname } }
      expect(response).to have_http_status(200)
      expect(assigns(:users_page).map(&:id).include?(a_client.id)).to be_truthy
    end

    it 'should be able to find it with names containing apostrophes on index page' do
      login_as(admin)
      post :index, params: { keyword: a_client.fname }
      expect(response).to have_http_status(200)
      expect(assigns(:users_page).map(&:id).include?(a_client.id)).to be_truthy
    end

    it 'should be able to find it with any number of empty spaces on index page' do
      login_as(admin)
      post :index, params: { keyword: randomize_empty_spaces(client.email) }
      expect(response).to have_http_status(200)
      expect(assigns(:users_page).map(&:id).include?(client.id)).to be_truthy
    end

    it 'should be able to find it with any number of empty spaces on find_results page' do
      login_as(admin)
      post :find_results, params: { keywords: { fname: randomize_empty_spaces(client.fname), lname: randomize_empty_spaces(client.lname), email: randomize_empty_spaces(client.email), nickname: randomize_empty_spaces(client.nickname) } }
      expect(response).to have_http_status(200)
      expect(assigns(:users_page).map(&:id).include?(client.id)).to be_truthy
    end

  end

  context 'personal details' do
    render_views

    describe 'login as client' do

      it 'should see resume' do
        login_as(client)
        get :show, params: { id: translator.id }
        expect(response.body.include?('<td width="164" rowspan="2" align="center" valign="top" class="blockTab tmarg7">Resume</td>')).to be_truthy
      end

      it 'should not see language description' do
        get :show, params: { id: other_translator.id }
        expect(response.body.include?('Translation languages')).to be_falsey
      end

    end

    describe 'login as translator' do

      it 'should see own resume' do
        login_as(translator)
        get :show, params: { id: translator.id }
        expect(response.body.include?('<td width="164" rowspan="2" align="center" valign="top" class="blockTab tmarg7">Resume</td>')).to be_truthy
      end

      it 'should see edit option for own resume' do
        login_as(translator)
        get :show, params: { id: translator.id }
        expect(response.body.include?('Create your resume')).to be_truthy
      end

      it 'should see translation languages for self' do
        login_as(translator)
        get :show, params: { id: translator.id }
        expect(response.body.include?('<td width="164" rowspan="2" align="center" valign="top" class="blockTab tmarg7">Translation languages</td>')).to be_truthy
      end

      it 'should be able to edit translation languages for self' do
        login_as(translator)
        get :show, params: { id: translator.id }
        expect(response.body.include?('Edit languages')).to be_truthy
      end

      it 'should see others resume' do
        login_as(translator)
        get :show, params: { id: other_translator.id }
        expect(response.body.include?('<td width="164" rowspan="2" align="center" valign="top" class="blockTab tmarg7">Resume</td>')).to be_truthy
      end

      it 'should not see edit option for others resume' do
        login_as(translator)
        get :show, params: { id: other_translator.id }
        expect(response.body.include?('Edit your resume')).to be_falsey
        expect(response.body.include?('Create your resume')).to be_falsey
      end

      it 'should not see translation languages for others' do
        login_as(translator)
        get :show, params: { id: other_translator.id }
        expect(response.body.include?('Translation languages')).to be_falsey
      end

      it 'should not be able to edit translation languages for other' do
        login_as(translator)
        get :show, params: { id: other_translator.id }
        expect(response.body.include?('Edit languages')).to be_falsey
      end

    end

    describe 'login as supporter' do

      it 'should see resume' do
        login_as(admin)
        get :show, params: { id: translator.id }
        expect(response.body.include?('<td width="164" rowspan="2" align="center" valign="top" class="blockTab tmarg7">Resume</td>')).to be_truthy
      end

      it 'should see translation languages' do
        login_as(admin)
        get :show, params: { id: translator.id }
        expect(response.body.include?('<td width="164" rowspan="2" align="center" valign="top" class="blockTab tmarg7">Translation languages</td>')).to be_truthy
      end

      it 'should be able to see clients profiles without errors' do
        login_as(admin)
        get :show, params: { id: client.id }
        expect(response).to have_http_status 200
      end

      describe 'GET #web_messages_list' do
        before(:each) do
          login_as(admin)
          get :web_messages_list, params: { id: client.id }
        end
        let(:expected_web_messages_count) do
          WebMessage.where(owner_id: client.id, owner_type: 'User').count
        end

        it 'displays the correct number of instant translations (web messages)' do
          expect(assigns(:pager).count).to eq(expected_web_messages_count)
        end

        it 'displays the correct number of pages' do
          expected_number_of_pages = expected_web_messages_count / PER_PAGE
          expect(assigns(:pager).number_of_pages).to eq(expected_number_of_pages)
        end
      end

    end

  end

end
