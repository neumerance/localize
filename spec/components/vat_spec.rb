require 'rails_helper'

describe Vat do
  let!(:client) { FactoryGirl.create(:client) }
  let!(:spain) { FactoryGirl.create(:country, :spanish_country) }
  let!(:spanish_client) { FactoryGirl.create(:client, zip_code: 35571, country: spain) }
  let!(:eu_country) { FactoryGirl.create(:country, :eu_country) }
  let!(:non_eu_country) { FactoryGirl.create(:country, :non_eu_country) }

  context 'Non EU' do
    it 'should return no vat' do
      vat = Vat.new(client, non_eu_country.id)
      expect(vat.get_user_tax_rate).to eq 0
    end
  end

  context 'EU' do
    it 'should return vat if vat_number is not present' do
      vat = Vat.new(client, eu_country.id)
      expect(eu_country.requiring_tax?).to be_truthy
      expect(vat.get_user_tax_rate).to eq eu_country.tax_rate
    end

    it 'should return vat if vat_number is not valid' do
      vat = Vat.new(client, eu_country.id, 'INVALIDVATNUMBER')
      expect(vat.get_user_tax_rate).to eq eu_country.tax_rate
    end

    it 'should not return vat if vat_number is present and valid' do
      vat = Vat.new(client, eu_country.id, '009270334B01')
      expect(vat.get_user_tax_rate).to eq 0
    end

    it 'should not ask vat to spanish client in canary islands' do
      vat = Vat.new(spanish_client)
      expect(vat.get_user_tax_rate).to eq 0
    end
  end
end
