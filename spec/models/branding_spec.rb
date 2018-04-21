require 'rails_helper'

describe Branding do
  context 'validations' do
    shared_examples 'has_base_validation_error' do
      it 'has validation error' do
        branding.valid?
        expect(branding.errors[field].first).to eq(message)
      end
    end

    context 'valid urls' do
      %w(logo_url home_url).each do |field|
        let(:branding) { build(:branding, field.to_sym => Faker::Crypto.md5) }
        let(:message) { 'must begin with HTTP:// or HTTPS://' }
        let(:field) { field.to_sym }
        include_examples 'has_base_validation_error'
      end
    end

    context 'valid size' do
      MAX_SIZE = { logo_width: 600, logo_height: 150 }.freeze
      %w(logo_height logo_width).each do |field|
        let(:branding) { build(:branding, field.to_sym => MAX_SIZE[field.to_sym] + 100) }
        let(:message) { 'cannot be larger than %d' % MAX_SIZE[field.to_sym] }
        let(:field) { field.to_sym }
        include_examples 'has_base_validation_error'
      end
    end

    context 'positive size' do
      %w(logo_height logo_width).each do |field|
        let(:branding) { build(:branding, field.to_sym => 0) }
        let(:message) { 'must be a positive number' }
        let(:field) { field.to_sym }
        include_examples 'has_base_validation_error'
      end
    end

    it 'should able to create branding' do
      brand = build(:branding)
      brand.valid?
      expect(brand.errors.size).to eq(0)
    end
  end
end
