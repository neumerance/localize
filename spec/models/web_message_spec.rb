require 'rails_helper'

describe WebMessage do
  let(:web_message) { build(:web_message) }

  describe '#price_per_word_for' do
    context 'when is a top client' do
      let(:client) { build(:client, top: true) }
      it 'should return price with discount' do
        expected = INSTANT_TRANSLATION_COST_PER_WORD * TOP_CLIENT_DISCOUNT
        expect(WebMessage.price_per_word_for(client)).to eq(expected)
      end
    end
    context 'when is a normal client' do
      let(:client) { build(:client) }
      it 'should return normal price' do
        expect(WebMessage.price_per_word_for(client)).to eq(INSTANT_TRANSLATION_COST_PER_WORD)
      end
    end
  end

  describe '#price_per_word' do
    context 'when is a website' do
      let(:web_message) { build(:web_message, owner: build(:website)) }
      it 'should try to get website translation contracts' do
        expect_any_instance_of(WebsiteTranslationContract::ActiveRecord_AssociationRelation).to receive(:first)
        web_message.price_per_word
      end
    end
    context 'when is a normal web message' do
      it 'should call #price_per_word_for' do
        expect(WebMessage).to receive(:price_per_word_for).with(web_message.client)
        web_message.price_per_word
      end
    end
  end

  describe '#translation_price' do
    it 'should calculate correctly' do
      expected_result = (web_message.word_count * web_message.price_per_word).ceil_money
      expect(web_message.translation_price).to eq(expected_result)
    end

    it 'should have translator_payment as alias' do
      expect(web_message.method(:translation_price)).to eq(web_message.method(:translator_payment))
    end
  end

  describe '#reviewer_payment' do
    it 'should return translation price * 0.5' do
      expected_result = web_message.translator_payment * 0.5
      expect(web_message.reviewer_payment).to eq(expected_result)

      allow(web_message).to receive(:translator_payment).and_return(10)
      expect(web_message.reviewer_payment).to eq(5)
    end
  end

  describe '#timeout' do
    context 'when translators has more than 5 minutes' do
      let(:minimum_words) { 10.minutes.to_i / MAX_TIME_TO_TRANSLATE_WORD }
      it 'should return valid amount of time' do

        word_counts = [6, 8, 10, 25, 122, 300]
        word_counts.each do |word_count|
          word_count += minimum_words
          web_message.word_count = word_count
          expect(web_message.timeout).to eq(word_count * MAX_TIME_TO_TRANSLATE_WORD)
        end
      end
    end

    context 'when translators has less than 10 minutes' do
      it 'should return at least 10 minutes' do
        web_message.word_count = 1
        expect(web_message.timeout).to eq(10.minutes.to_i)
      end
    end
  end

  describe '#translation_complete?' do
    subject { web_message.translation_complete? }
    it 'should return false for non completed requests' do
      expect(subject).to be_falsey
    end

    it 'should return true for completed requests' do
      web_message.translation_status = TRANSLATION_COMPLETE
      expect(subject).to be_truthy
    end
  end

  describe '#user_can_edit?' do
    it 'should return false if given user is not the translator' do
      other_translator = build(:translator)
      expect(
        web_message.user_can_edit?(other_translator)
      ).to be_falsey
    end
    it 'should return true for the allowed statuses' do
      allowed_statuses = [TRANSLATION_IN_PROGRESS,
                          TRANSLATION_NEEDS_EDIT,
                          TRANSLATION_COMPLETE]

      allowed_statuses.each do |status|
        web_message.translation_status = status
        expect(
          web_message.user_can_edit?(web_message.translator)
        ).to be_truthy
      end
    end
    it 'should return false for other statuses' do
      not_allowed_statuses = [TRANSLATION_PENDING_CLIENT_REVIEW,
                              TRANSLATION_NOT_NEEDED,
                              TRANSLATION_NEEDED,
                              TRANSLATION_REFUSED,
                              TRANSLATION_NOT_DELIVERED]

      not_allowed_statuses.each do |status|
        web_message.translation_status = status
        expect(
          web_message.user_can_edit?(web_message.translator)
        ).to be_falsey
      end
    end
  end

  describe '#remaining_time' do
    subject { web_message.remaining_time }
    before do
      allow(web_message).to receive(:timeout).and_return(5.minutes.to_i)
    end

    it 'should return the right amount after some seconds' do
      web_message.translate_time = 10.seconds.ago
      expect(subject).to be_within(2).of(290)
    end

    it 'should return negative value if no more time' do
      web_message.translate_time = 1.hour.ago
      expect(subject).to be < 0
    end
  end

  describe '#has_time?' do
    it 'should return true if has time' do
      allow(web_message).to receive(:remaining_time).and_return(10)
      expect(web_message.has_time?).to be_truthy
    end

    it 'should return false if does not has time' do
      allow(web_message).to receive(:remaining_time).and_return(0)
      expect(web_message.has_time?).to be_falsey
    end

    it 'should return false if remaining time is negative' do
      allow(web_message).to receive(:remaining_time).and_return(-100)
      expect(web_message.has_time?).to be_falsey
    end
  end

  %w(client_body visitor_body).each do |field|
    context "validating field #{field}" do

      let(:web_message) { build(:web_message, field.to_sym => Faker::Lorem.words(COMMON_NOTE / 4).join(' ')) }

      it "should not allow client #{field} length more than #{COMMON_NOTE}" do
        web_message.valid?
        expect(web_message.errors[field.to_sym].first).to eq("is too long (maximum is #{COMMON_NOTE} characters)")
      end

    end
  end

end
