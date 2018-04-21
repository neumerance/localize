require 'rails_helper'

# This test a monkey patch required to make Rumoji gem works for our purpose
describe Rumoji do

  describe '.encode' do
    it 'should not encode 3 byte longs symbols' do
      string = "I'm a ☔️"
      expect(Rumoji.encode(string)).to eq(string)
    end

    it 'should not encode 3 byte longs emojis' do
      string = 'tres tristes ©'
      expect(Rumoji.encode(string)).to eq(string)
    end

    it 'should return same string if no emojis are present' do
      string = 'testing without emojis'
      expect(Rumoji.encode(string)).to eq(string)
    end

    it 'should return encoded emojis' do
      string = 'I want a raise! 🙋'
      expected_string =  'I want a raise! :raised_hand:'
      expect(Rumoji.encode(string)).to eq(expected_string)
    end
  end
end
