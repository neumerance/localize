require 'rails_helper'
require 'support/utils_helper'

RSpec.describe 'Finance', type: :request do
  include Rack::Test::Methods
  include ActionDispatch::TestProcess
  include UtilsHelper

  describe 'POST paypal_ipn' do
    before do
      ActionController::Base.forgery_protection_origin_check = true
      ActionController::Base.allow_forgery_protection = true
    end

    after do
      ActionController::Base.allow_forgery_protection = false
      ActionController::Base.forgery_protection_origin_check = false
    end
    it 'should not raise CSRF exceptions' do
      expect do
        post('/finance/paypal_ipn', params: { test: 123 })
      end.to_not raise_error(ActionController::InvalidAuthenticityToken)
    end

  end

end
