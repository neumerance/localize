require 'rails_helper'

describe StringTranslation do
  let(:text_resource) { create(:text_resource) }
  let(:resource_string) { create(:resource_string, txt: Faker::Lorem.words(3).join(' '), text_resource: text_resource) }
  let!(:resource_language) { create(:resource_language, :with_account, account_balance: 100, text_resource: text_resource, language_id: 1) }

  context '#refund' do
    let(:string_translation) do
      create(:string_translation, resource_string: resource_string, status: STRING_TRANSLATION_BEING_TRANSLATED, language_id: 1)
    end

    subject { string_translation.refund }

    before :each do
      allow(string_translation.text_resource).to receive_message_chain(:client, :money_account)
      allow(MoneyTransactionProcessor).to receive(:transfer_money)
    end

    it 'should return if status is not BEING_TRANSLATED' do
      string_translation.status = 0
      expect(string_translation.resource_string).to_not receive(:txt)
      expect(subject).to eq(false)
    end

    it 'should call transfer money with right amount' do
      words = resource_string.txt.count_words
      amount = words * resource_language.translation_amount

      expect(MoneyTransactionProcessor).to receive(:transfer_money).with(
        anything,
        anything,
        amount,
        DEFAULT_CURRENCY_ID,
        TRANSFER_REFUND_FOR_RESOURCE_TRANSLATION
      )

      subject
    end

    it 'should update string_translation status to missing funds' do
      expect(string_translation).to receive(:save)
      expect { subject }.to change(string_translation, :status).to(STRING_TRANSLATION_MISSING)
    end

    it 'should call update_word_count on resource language' do
      expect_any_instance_of(ResourceLanguage).to receive(:update_word_count).once
      subject
    end
  end

  context '#refund_review' do
    let(:string_translation) do
      create(:string_translation, resource_string: resource_string, review_status: REVIEW_PENDING_ALREADY_FUNDED, language_id: 1)
    end

    subject { string_translation.refund_review }

    before :each do
      allow(string_translation.text_resource).to receive_message_chain(:client, :money_account)
      allow(MoneyTransactionProcessor).to receive(:transfer_money)
    end

    it 'should return if status is not CORRECT' do
      string_translation.review_status = :abc
      expect(string_translation.resource_string).to_not receive(:txt)
      expect(subject).to eq(false)
    end

    it 'should call transfer money with right amount' do
      words = resource_string.txt.count_words
      amount = words * resource_language.review_amount

      expect(MoneyTransactionProcessor).to receive(:transfer_money).with(
        anything,
        anything,
        amount,
        DEFAULT_CURRENCY_ID,
        TRANSFER_REFUND_FOR_RESOURCE_TRANSLATION
      )

      subject
    end

    it 'should update string_translation status to missing funds' do
      expect(string_translation).to receive(:save)
      expect { subject }.to change(string_translation, :review_status).to(REVIEW_NOT_NEEDED)
    end
  end

end
