require 'rails_helper'

describe Shortcode do

  context 'validation' do
    let(:shortcode) { build(:shortcode, comment: Faker::Lorem.words(COMMON_FIELD / 4).join(' ')) }

    it 'should validate presence of txt' do
      shortcode.valid?
      expect(shortcode.errors[:comment].first).to eq("is too long (maximum is #{COMMON_FIELD} characters)")
    end

  end

end
