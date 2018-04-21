require 'spec_helper'
require 'rails_helper'
require 'support/utils_helper'

describe SupportController, type: :controller do
  include ActionDispatch::TestProcess
  include UtilsHelper

  let!(:supporter) { FactoryGirl.create(:supporter) }
  let!(:support_ticket) { FactoryGirl.create(:support_ticket, supporter: supporter) }

  context 'supporter logged in' do

    10.times do
      it 'should be able to reply to a ticket' do
        login_as(supporter)
        messages_count = support_ticket.messages.count
        post :create_message, params: { id: support_ticket.id, body: Faker::Lorem.words(100).join(' ') }
        expect(response).to have_http_status(302)
        expect(support_ticket.reload.messages.count).to eq(messages_count + 1)
      end
    end

    it 'should be able to start new help request' do
      login_as(supporter)
      get :new, params: { help_setup: 1 }
      expect(response).to have_http_status(200)
    end

  end
end
