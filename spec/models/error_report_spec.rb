require 'rails_helper'

describe ErrorReport do

  context 'validation' do
    let(:error_report) { build(:error_report, resolution: Faker::Lorem.words(COMMON_NOTE / 4).join(' ')) }

    it "should not allow description length more that #{COMMON_NOTE}" do
      error_report.valid?
      expect(error_report.errors[:resolution].first).to eq("is too long (maximum is #{COMMON_NOTE} characters)")
    end
  end

end
