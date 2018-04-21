require 'rails_helper'

describe Revision do

  context 'validation' do
    let(:revision) { build(:revision, description: Faker::Lorem.words(COMMON_NOTE / 4).join(' ')) }

    it 'should validate presence of txt' do
      revision.valid?
      expect(revision.errors[:description].first).to eq("is too long (maximum is #{COMMON_NOTE} characters)")
    end

  end

end
