require 'spec_helper'
require 'rails_helper'

describe WebsiteTranslationOffersController do

  include ActiveSupport::Testing::Assertions
  fixtures :websites

  before(:all) { @template = 'website_translation_offers/create.json.erb' }

  describe 'POST websites' do
    before(:each) { @request.env['HTTP_ACCEPT'] = 'application/json' }
    let(:verb) { :post }
    let(:action) { :create }
    let(:website) { websites(:amir_wp) }
    let(:use_website_id) { true }
    it_should_behave_like 'require website id and accesskey'

    context 'when parameters are correct' do
      it 'website translation offer is created' do
        assert_difference 'WebsiteTranslationOffer.count', 1 do
          post(:create, params: post_wto_params(website), 'HTTP_ACCEPT' => 'application/json')
          expect(response).to have_http_status(:success)
        end
      end
    end

    context 'with unexistent languange to' do
      # this spec is duplicate and wrong -> see line 47
      # it "website translation offer is not created" do
      #   assert_no_difference 'WebsiteTranslationOffer.count' do
      #     params = post_wto_params(website)
      #     params[:target_language] = "foo"
      #     post(:create, params, nil, {'HTTP_ACCEPT' => "application/json"})
      #     expect(response).to have_http_status(:success)
      #   end
      # end
      it 'return the correct error code' do
        params = post_wto_params(website)
        params[:source_language] = 'foo'
        post(:create, params: params, 'HTTP_ACCEPT' => 'application/json')
        expect(assigns(:json_code)).to eq(LANGUAGE_NOT_FOUND)
      end
    end

    context 'without source language' do
      it 'website translation offer is not created' do
        assert_no_difference 'WebsiteTranslationOffer.count' do
          params = post_wto_params(website)
          params.delete(:source_language)
          post(:create, params: params, 'HTTP_ACCEPT' => 'application/json')
          # INVALID_PARAMS is being raised instead of WEBSITE_TRANSLATION_OFFER_NOT_CREATED
          # because the :source_language parameters is deleted.
          # therefore the web translation offer is not been created.
          # Todo: There should be a new scenario that will raise
          #       WEBSITE_TRANSLATION_OFFER_NOT_CREATED without raising INVALID_PARAMS
          expect(assigns(:json_code)).to eq(INVALID_PARAMS)
        end
      end
      it 'return the correct error code' do
        params = post_wto_params(website)
        params.delete(:source_language)
        post(:create, params: params, 'HTTP_ACCEPT' => 'application/json')
        expect(assigns(:json_code)).to eq(INVALID_PARAMS)
      end
    end

    context 'with unexistent source languange' do
      it 'website translation offer is not created' do
        assert_no_difference 'WebsiteTranslationOffer.count' do
          params = post_wto_params(website)
          params[:source_language] = 'foo'
          post(:create, params: params, 'HTTP_ACCEPT' => 'application/json')
        end
      end
      it 'return the correct error code' do
        params = post_wto_params(website)
        params[:source_language] = 'foo'
        post(:create, params: params, 'HTTP_ACCEPT' => 'application/json')
        expect(assigns(:json_code)).to eq(LANGUAGE_NOT_FOUND)
      end
    end
  end

  private

  def post_wto_params(website)
    {
      api_version: '1.0',
      project_id: website.id,
      accesskey: website.accesskey,
      website_id: website.id,
      source_language: 'German',
      target_language: 'French'
    }
  end
end
