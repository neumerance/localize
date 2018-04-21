require 'spec_helper'
require 'rails_helper'

describe DestinationsController, type: :controller do
  fixtures :users, :user_sessions
  describe 'update' do
    let(:destination) { create(:destination) }
    let(:session) { user_sessions(:supporter) }

    it 'respond' do
      post :update, params: { id: destination.id, destination: { name: Faker::Name.name }, session: session.session_num }
      expect(response).to redirect_to(destination_path(destination.id))
    end
  end

end
