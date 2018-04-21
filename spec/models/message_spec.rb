require 'rails_helper'

describe Message do
  let(:message) { build(:message) }

  context 'validation' do
    let(:message) { build(:message, body: Faker::Lorem.words(COMMON_NOTE / 4).join(' ')) }

    it 'should validate presence of txt' do
      message.valid?
      expect(message.errors[:body].first).to eq("is too long (maximum is #{COMMON_NOTE} characters)")
    end
  end

  context 'callbacks' do
    it 'should call encode_emojis' do
      expect(message).to receive(:encode_emojis)
      message.save
    end
  end

  context '#encode_emojis' do
    it 'should call Rumoji#encode' do
      expect(Rumoji).to receive(:encode)
      message.save
    end

    it 'Should assing returned value from Rumoji#encode to body' do
      message.body = 'Original'
      allow(Rumoji).to receive(:encode).and_return('Modified')
      message.save
      expect(message.body).to eq('Modified')
    end

    it 'should convert emoji to text' do
      # Note: we should not test Rumoji but lets do just for fun.
      rage = "\xF0\x9F\x98\xA1"
      message.body = "the emoji is #{rage}"
      message.save
      expect(message.body).to include(':rage:')
    end
  end

  context '#body_with_emojis' do
    it 'should call Rumoji#decode' do
      expect(Rumoji).to receive(:decode)
      message.body_with_emojis
    end
  end

end
