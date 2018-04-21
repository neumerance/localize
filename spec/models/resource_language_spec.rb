require 'rails_helper'

describe ResourceLanguage do
  let!(:client) { create(:client) }
  let!(:text_resource) { create(:text_resource, client: client) }
  let!(:single_language_id) { [Language.first.id] }
  before(:each) do
    text_resource.add_languages(single_language_id)
    @resource_language = text_resource.resource_languages.first
    create(:resource_strings_with_string_translations, text_resource: text_resource)
    create :resource_chat, resource_language: resource_language
  end

  let(:resource_language) { text_resource.resource_languages.first }

  describe '#refund_review' do
    before :each do
      client.find_or_create_account(DEFAULT_CURRENCY_ID)

      @base_balance = 10
      resource_language.money_account.update_attribute :balance, @base_balance

      @string = resource_language.string_translations.first
      @string.status = STRING_TRANSLATION_BEING_TRANSLATED
      @string.review_status = REVIEW_PENDING_ALREADY_FUNDED
      @string.save
    end

    subject { resource_language.refund_review }

    it 'should return if managed work is not active' do
      resource_language.managed_work.active = false
      expect(resource_language).to_not receive(:funded_words_pending_review_count)
      expect(subject).to be_nil
    end

    it 'shoud rollback unused funds' do
      words_funded_for_review = resource_language.funded_words_pending_review_count

      amount = words_funded_for_review * resource_language.review_amount

      resource_language.refund_review

      expected_amount = (@base_balance - amount).ceil_money.to_d
      expect(resource_language.money_account.balance).to eq(expected_amount)
    end

    it 'should move strings from funded, pending review to not yet funded' do
      resource_language.refund_review
      @string.reload
      expect(@string.review_status).to eq(REVIEW_NOT_NEEDED)
    end
  end
end
