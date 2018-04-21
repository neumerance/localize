require 'rails_helper'

describe Newsletter do

  context 'validation' do

    let(:newsletter) { build(:newsletter, body: Faker::Lorem.words(COMMON_NOTE / 5).join(' ')) }

    it "should not allow body text length more than #{COMMON_NOTE}" do
      newsletter.valid?
      expect(newsletter.errors[:body].first).to eq("is too long (maximum is #{COMMON_NOTE} characters)")
    end

  end

  context 'bluecloth' do
    let(:newsletter) { build(:newsletter, body: '窶冲') }

    it 'should able to parse chinese chars' do
      expect(newsletter.body_markup(true)).not_to be_nil
    end

  end

end
