require 'rails_helper'

describe 'website_translation_offers/create' do

  before(:all) { @template = 'website_translation_offers/create.json.erb' }

  context 'when parameters are correct' do
    it_should_behave_like 'json success'
  end
end
