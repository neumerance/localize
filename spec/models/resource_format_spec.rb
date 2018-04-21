require 'rails_helper'

describe ResourceFormat do

  context 'validation' do
    let(:resource_format) { build(:resource_format, description: Faker::Lorem.words(COMMON_FIELD / 4).join(' ')) }

    it "should not allow description length more that #{COMMON_FIELD}" do
      resource_format.valid?
      expect(resource_format.errors[:description].first).to eq("is too long (maximum is #{COMMON_FIELD} characters)")
    end
  end

end
