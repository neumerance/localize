require 'rails_helper'

describe Shortcode do

  context 'validation' do
    let(:download) { build(:download, notes: Faker::Lorem.words(COMMON_FIELD / 4).join(' ')) }

    it 'should validate presence of txt' do
      download.valid?
      expect(download.errors[:notes].first).to eq("is too long (maximum is #{COMMON_FIELD} characters)")
    end

  end

end
