require 'spec_helper'
require 'rails_helper'
require 'support/utils_helper'

describe FinanceController, type: :controller do
  render_views
  include ActionDispatch::TestProcess
  include UtilsHelper

  let!(:client) { FactoryGirl.create(:client, :with_money_account) }
  # let!(:money_account) { FactoryGirl.create(:user_account, owner_id: client.id) }
  let!(:supporter) { FactoryGirl.create(:admin) }
  let!(:country) { FactoryGirl.create(:country, :luxembourg) }
  let!(:invoice) { FactoryGirl.create(:invoice, user_id: client.id, source_id: client.id, source_type: 'User') }
  let!(:partner) { FactoryGirl.create(:partner) }

  context 'VAT percent' do

    it 'should be based on the country' do
      login_as(client)
      get :invoice, params: { id: invoice.id }
      expect(response).to have_http_status(200)
      expect(response.body).to include('<td>VAT Tax in Luxembourg (17.0%) </td>')
    end

    it 'should not change when is changed on the country' do
      login_as(client)
      country.update_attribute(:tax_rate, 10.0)
      get :invoice, params: { id: invoice.id }
      expect(response).to have_http_status(200)
      expect(response.body).to include('<td>VAT Tax in Luxembourg (17.0%) </td>')
    end

  end

  context 'invoices' do
    render_views

    it 'should have option to view/download invoice as pdf on invoice list' do
      login_as(client)
      get :invoices
      expect(response).to have_http_status(200)
      expect(response.body).to include('View')
      expect(response.body).to include("<a href=\"/finance/invoice/#{invoice.id}.pdf\">PDF</a>")
      expect(response.body).to include("<a href=\"/finance/invoice/#{invoice.id}.pdf?disp=attachment\">PDF</a>")
    end

    it 'should be able to see HTML invoice' do
      login_as(client)
      get :invoice, params: { id: invoice.id }
      expect(response).to have_http_status(200)
    end

    it 'should be able to see PDF invoice' do
      login_as(client)
      get :invoice, id: invoice.id, format: 'pdf'
      expect(response).to have_http_status(200)
    end

    describe 'on invoice details' do

      before do
        @invoice_with_vat = FactoryGirl.create(:invoice_with_vat)
        @client = @invoice_with_vat.source
        login_as(@client)
      end

      it 'should show corect vat' do
        get :invoice, id: @invoice_with_vat.id
        expect(response).to have_http_status(200)
        expect(response.body.include?("VAT Tax in #{Country.find(@invoice_with_vat.tax_country_id).name} (#{@invoice_with_vat.tax_rate}%)")).to be_truthy
        expect(response.body.include?("#{@invoice_with_vat.tax_amount} <acronym title=\"USD\">USD</acronym>")).to be_truthy
      end

      it 'should show corect deposit' do
        get :invoice, id: @invoice_with_vat.id
        expect(response).to have_http_status(200)
        expect(response.body.include?('Deposit to your ICanLocalize account for translation work')).to be_truthy
        expect(response.body.include?("#{@invoice_with_vat.gross_amount} <acronym title=\"USD\">USD</acronym>")).to be_truthy
      end

      it 'should show corect total' do
        get :invoice, id: @invoice_with_vat.id
        expect(response).to have_http_status(200)
        expect(response.body.include?('Total')).to be_truthy
        expect(response.body.include?("#{@invoice_with_vat.gross_amount + @invoice_with_vat.tax_amount} USD")).to be_truthy
      end

    end

  end

  context '#account_history' do
    it 'should redirect with a warning message if account is not found' do
      login_as(client)
      get :account_history, params: { id: -1 }
      expect(response).to have_http_status 302
    end

    context 'when logged it as supporter' do

      it 'should allow to view any account' do
        login_as(supporter)
        get :account_history, params: { id: client.money_account.id }
        expect(response).to have_http_status 200
      end

      it 'should redirect if account doesnt exists' do
        login_as(supporter)
        get :account_history, params: { id: -1 }
        expect(response).to have_http_status 302
      end
    end

    it 'should not allow clients to view other customers account' do
      login_as(client)
      get :account_history, params: { id: -1 }
      expect(response).to have_http_status 302
    end
  end

  context 'partner' do
    it 'should be able to see index without errors' do
      login_as(partner)
      get :index
      expect(response).to have_http_status 302
    end
  end

end
