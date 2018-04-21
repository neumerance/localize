require 'rails_helper'

describe Voucher do
  describe 'validations' do
    it 'should not create duplicate' do
      first = create(:voucher)
      voucher = build(:voucher, code: first.code)
      voucher.valid?
      expect(voucher.errors[:code].size).to eq(1)
    end

    it 'should able to create voucher with valid values' do
      voucher = build(:voucher)
      voucher.valid?
      expect(voucher.errors.size).to eq(0)
    end

    %w(code amount comments).each do |field|
      it "should validate presence of #{field}" do
        voucher = build(:voucher, field.to_sym => nil)
        voucher.valid?
        expect(voucher.errors[field.to_sym].size).to eq(1)
      end
    end

    context 'comment length' do
      let(:failing_voucher) { build(:voucher, comments: Faker::Lorem.words(COMMON_NOTE / 4).join(' ')) }

      it "should not allow comments text length more than #{COMMON_NOTE}" do
        failing_voucher.valid?
        expect(failing_voucher.errors[:comments].first).to eq("is too long (maximum is #{COMMON_NOTE} characters)")
      end
    end

  end
end
