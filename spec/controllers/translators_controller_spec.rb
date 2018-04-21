require 'spec_helper'
require 'rails_helper'

RSpec.describe TranslatorsController, type: :controller do
  describe 'GET Show' do
    context 'with invalid translator id' do
      it 'should return 404' do
        get :show, params: { id: 0 }
        expect(response.status).to be 404
      end
    end
  end
end
