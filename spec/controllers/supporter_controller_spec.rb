require 'spec_helper'
require 'rails_helper'
require 'support/utils_helper'

describe SupporterController, type: :controller do
  include ActionDispatch::TestProcess
  include UtilsHelper

  let!(:supporter) { FactoryGirl.create(:supporter) }
  let!(:website) { FactoryGirl.create(:website, :english_to_german_language_pair_offer) }
  let!(:translators) { FactoryGirl.create_list(:translator, 3, :translator_languages_auto_assignment) }
  let!(:reviewers) { FactoryGirl.create_list(:translator, 2) }

  context 'POST assign_translators_to_language_pair' do

    before(:each) do
      login_as(supporter)
    end

    it 'should able to assign translators and reviewer to language pair' do
      params = { format: :js }
      params[:website_translation_offer_id] = website.website_translation_offers.first.id
      params[:translators] = translators.map { |translator| { type: 'translator', id: translator.id } }
      params[:translators] << { type: 'reviewer', id: reviewers.first.id }
      post :assign_translators_to_language_pair, params: params
      expect(response).to have_http_status(200)
      # expect(assigns(:result).last).to eq(0)
      expect(assigns(:result).select { |x| x['is_assigned'] && x['type'] == 'translator' }.size).to eq(translators.size)
      expect(assigns(:result).select { |x| x['is_assigned'] && x['type'] == 'reviewer' }.size).to eq(0)
    end

    it 'should not allow to assign review to language pair with existing reviewer' do
      params = { format: :js }
      params[:website_translation_offer_id] = website.website_translation_offers.first.id
      params[:translators] = reviewers.map { |translator| { type: 'reviewer', id: translator.id } }
      post :assign_translators_to_language_pair, params: params
      expect(response).to have_http_status(200)
      expect(assigns(:result).select { |x| x['is_assigned'] && x['type'] == 'reviewer' }.size).to eq(0)
      unassigned = assigns(:result).select { |x| !x['is_assigned'] && x['type'] == 'reviewer' }
      expect(unassigned.size).to eq(2)
      expect(unassigned.first['reason'].present?).to be_truthy
    end

  end

end
