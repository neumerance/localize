require 'rails_helper'

RSpec.describe 'Its', type: :request do

  let!(:translator) { FactoryGirl.create(:translator) }
  let!(:headers) { { 'CONTENT_TYPE' => 'application/json', 'ACCEPT' => 'application/json' } }

  describe 'POST /its/' do

  end

end
