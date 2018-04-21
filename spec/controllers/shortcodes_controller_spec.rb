require 'spec_helper'
require 'rails_helper'
require 'support/utils_helper'

describe ShortcodesController, type: :controller do
  include ActionDispatch::TestProcess
  include UtilsHelper

  let!(:user) { FactoryGirl.create(:client) }
  let!(:website) { FactoryGirl.create(:website, client_id: user.id) }
  let!(:shortcode) { FactoryGirl.create(:shortcode, website_id: website.id) }

  it 'should toggle without error' do
    login_as(user)
    post :toggle_enabled, id: shortcode.id, website_id: website.id
    expect(:response).to redirect_to(shortcodes_url)
  end

end
