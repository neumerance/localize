require 'spec_helper'
require 'rails_helper'
require 'support/utils_helper'

describe LoginController, type: :controller do
  include ActionDispatch::TestProcess
  include UtilsHelper

  context 'login' do

    let!(:client) { FactoryGirl.create(:client, email: 'SoMeEmAiL@ICanLocaliZe.CoM', password: '123456') }

    5.times do
      it 'should be able to login with any email capitalization' do
        post :login, params: { email: randomize_case(client.email), password: client.password }
        expect(response).to have_http_status(302)
        expect(assigns(:user).id).to eq(client.id)
        expect(response).to redirect_to(controller: :client, action: :getting_started)
      end
    end

  end

  context 'bugfixes' do
    it 'should not raise double render' do
      get :complete_registration, params: {
        id: 'index',
        format: 'php'
      }
      expect(flash[:notice]).to eq('User not found')
    end
  end

end
