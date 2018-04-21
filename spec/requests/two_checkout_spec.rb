require 'rails_helper'

RSpec.describe '2Checkout', type: :request do
  # See https://www.2checkout.com/documentation/notifications/
  describe 'notifications' do
    before(:each) do
      # Clear the test DB
      # As long as config.use_transactional_fixtures = true, this deletion is
      # executed within a transaction and rolled back after each test.
      LanguagePairFixedPrice.delete_all
      Language.delete_all
      PendingMoneyTransaction.delete_all
    end

    let!(:client) { FactoryGirl.create(:client) }
    let!(:money_account) { client.create_default_money_account }
    let!(:website) { FactoryGirl.create(:website, client: client, api_version: '2.0') }

    let(:english) do
      FactoryGirl.create(:english_language, skip_language_pairs_creation: true)
    end

    let(:french) do
      FactoryGirl.create(:french_language, skip_language_pairs_creation: true)
    end

    let!(:language_pair_fixed_price) do
      FactoryGirl.create(
        :language_pair_fixed_price,
        from_language: english,
        to_language: french,
        actual_price: 0.10
      )
    end

    let!(:wto) do
      FactoryGirl.create(
        :website_translation_offer,
        from_language: english,
        to_language: french,
        automatic_translator_assignment: true,
        website: website
      )
    end

    let!(:cms_request) do
      FactoryGirl.create(
        :cms_request,
        website: website,
        # Source language
        language: english,
        review_enabled: false,
        cms_target_language: FactoryGirl.create(
          :cms_target_language,
          language: french,
          word_count: 100,
          # Not yed funded
          status: CMS_TARGET_LANGUAGE_CREATED
        )
      )
    end

    # 200 words (2 cms requests with 100 words each) * 0.10 per word. Review
    # is disabled.
    let!(:amount_without_taxes) { 20.00 }

    let!(:invoice) do
      FactoryGirl.create(
        :invoice,
        status: TXN_CREATED,
        payment_processor: EXTERNAL_ACCOUNT_2CHECKOUT,
        user: client,
        source: website,
        gross_amount: amount_without_taxes,
        cms_requests: [cms_request]
      )
    end

    let(:valid_parameters) do
      # Only include the essential (required) parameters
      { message_type: 'FRAUD_STATUS_CHANGED',
        fraud_status: 'pass',
        # ID of ICL invoice
        vendor_order_id: invoice.id,
        # 2CO invoice (not the ICL invoice)
        invoice_id: '206402213621',
        invoice_list_amount: '300.00',
        sale_id: '206402213609',
        # md5 hash matches the sale_id and invoice_id.
        # Values taken from a real request in the
        # production log.
        md5_hash: 'D62AA1D7660452DABCB5975140EEE580' }
    end

    context 'on successful payment in WPML 3.9+ flow' do
      it 'Creates a PendingMoneyRequest for each cms_request' do
        post '/two_checkout/notification', valid_parameters
        expect(response).to have_http_status(200)
        expect(cms_request.reload.pending_money_transaction.amount).to eq 10
      end
    end
  end
end
