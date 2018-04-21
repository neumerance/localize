require 'rails_helper'

RSpec.describe LanguagePairFixedPrice, type: :model do
  before(:each) do
    # Clear the test DB
    # As long as config.use_transactional_fixtures = true, this deletion is
    # executed within a transaction and rolled back after each test. That
    # means other specs which rely on preexisting records in the test DB will
    # not be affected.
    LanguagePairFixedPrice.delete_all
    Language.delete_all
    WebsiteTranslationOffer.delete_all
    WebsiteTranslationContract.delete_all
  end

  let(:language_pair1) do
    FactoryGirl.create(:language_pair_fixed_price,
                       :with_contracts_and_offer,
                       calculated_price: MINIMUM_FIXED_PRICE,
                       average_contract_price: 0.12,
                       published: false)
  end

  let(:language_pair2) do
    FactoryGirl.create(:language_pair_fixed_price,
                       :with_contracts_and_offer,
                       from_language: language_pair1.to_language,
                       to_language: language_pair1.from_language,
                       calculated_price: MINIMUM_FIXED_PRICE,
                       average_contract_price: 0.15,
                       published: false)
  end

  describe '.known_language_pair?' do
    subject { described_class.known_language_pair?(language_pair2.from_language, language_pair2.to_language) }

    it 'should lookup for the language pair' do
      expect(described_class).to receive(:get_language_pair).with(language_pair2.from_language, language_pair2.to_language)
      subject
    end

    it 'should return false if some error is raised' do
      allow(described_class).to receive(:get_language_pair).and_return(false)
      expect(subject).to be_falsey
    end

    it 'should return right status for pair' do
      expect(language_pair1.known_language_pair?).to be_falsey
      expect(language_pair2.known_language_pair?).to be_falsey
      language_pair1.update_attribute(:published, true)
      expect(language_pair1.reload.known_language_pair?).to be_truthy
    end

  end

  describe '.get_language_pair' do
    it 'returns a language pair' do
      expect(
        LanguagePairFixedPrice.get_language_pair(language_pair1.from_language,
                                                 language_pair1.to_language)
      ).to eq(language_pair1)
    end
  end

  describe '.get_price' do
    context 'when calculated_price is lesser than MINIMUM_FIXED_PRICE' do
      it 'returns the MINIMUM_FIXED_PRICE' do
        language_pair = FactoryGirl.create(
          :language_pair_fixed_price,
          calculated_price: MINIMUM_FIXED_PRICE - 0.01
        )
        expect(
          LanguagePairFixedPrice.get_price(language_pair.from_language,
                                           language_pair.to_language)
        ).to eq MINIMUM_FIXED_PRICE
      end
    end

    context 'when calculated_price is equal or greater than MINIMUM_FIXED_PRICE' do
      it 'returns the calculated_price' do
        language_pair = FactoryGirl.create(
          :language_pair_fixed_price,
          calculated_price: MINIMUM_FIXED_PRICE + 0.01
        )
        expect(
          LanguagePairFixedPrice.get_price(language_pair.from_language,
                                           language_pair.to_language)
        ).to eq MINIMUM_FIXED_PRICE + 0.01
      end
    end
  end

  describe '.set_price' do
    it 'sets the actual_price with two decimal places' do
      LanguagePairFixedPrice.set_price(language_pair1.from_language,
                                       language_pair1.to_language,
                                       0.1535645)
      expect(language_pair1.reload.actual_price).to eq 0.15
    end
  end

  describe 'price calculations' do
    context 'when created with nil calculated_price and actual_price' do
      # The :with_contracts_and_offer trait does not work with
      # this specific test as the website_translation_contracts
      # and website_translator_offer are only created after
      # language_pair_fixed_price. Hence, when the
      # before_validation :set_calculated_price callback of the
      # LanguagePairFixedPrices is executed, the data required to calculate
      # the average price does not yet exist.That's why creating all of the
      # following test data "manually" is necessary.
      let!(:from_language) do
        FactoryGirl.create(:english_language,
                           skip_language_pairs_creation: true)
      end

      let!(:to_language) do
        FactoryGirl.create(:german_language,
                           skip_language_pairs_creation: true)
      end

      let!(:two_year_old_contract) do
        FactoryGirl.create(
          :website_translation_contract,
          status: 2,
          amount: 0.15,
          created_at: 2.years.ago,
          translator: FactoryGirl.create(:translator)
        )
      end

      let!(:two_month_old_contract) do
        FactoryGirl.create(
          :website_translation_contract,
          status: 2,
          amount: 0.17,
          created_at: 2.months.ago,
          translator: FactoryGirl.create(:translator)
        )
      end

      let!(:two_day_old_contract) do
        FactoryGirl.create(
          :website_translation_contract,
          status: 2,
          amount: 0.19,
          created_at: 2.days.ago,
          translator: FactoryGirl.create(:translator)
        )
      end

      let!(:language_pair_fixed_price) do
        FactoryGirl.create(
          :language_pair_fixed_price,
          from_language: from_language,
          to_language: to_language,
          calculated_price: 0.17,
          actual_price: 0.09,
          number_of_transactions: 3,
          calculated_price_last_year: 0.18,
          number_of_transactions_last_year: 2,
          published: false
        )
      end

      let!(:website_translation_offer) do
        FactoryGirl.create(
          :website_translation_offer,
          from_language: from_language,
          to_language: to_language,
          website_translation_contracts: [two_year_old_contract,
                                          two_month_old_contract,
                                          two_day_old_contract]
        )
      end

      it 'it calculates and sets the calculated_price attribute' do
        expect(language_pair_fixed_price.calculated_price).to eq 0.17
      end

      it 'it calculates and sets the number_of_transactions attribute' do
        expect(language_pair_fixed_price.number_of_transactions).to eq 3
      end

      it 'it calculates and sets the calculated_price_last_year attribute' do
        expect(language_pair_fixed_price.calculated_price_last_year).to eq 0.18
      end

      it 'it calculates and sets the number_of_transactions_last_year attribute' do
        expect(language_pair_fixed_price.number_of_transactions_last_year).to eq 2
      end

      it 'it calculates and sets the actual_price attributes' do
        expect(language_pair_fixed_price.actual_price).to eq 0.17
      end
    end

    describe '.recalculate_prices' do
      it 'recalculates the price for a single language pair' do
        LanguagePairFixedPrice.recalculate_prices(language_pair1)
        expect(language_pair1.reload.actual_price).to eq 0.12
      end

      it 'recalculates the price for all given language pairs' do
        LanguagePairFixedPrice.recalculate_prices([language_pair1,
                                                   language_pair2])
        expect(language_pair1.reload.actual_price).to eq 0.12
        expect(language_pair2.reload.actual_price).to eq 0.15
      end

      it 'when given no arguments, recalculates prices of all language pairs' do
        # Trigger lazy creation of language pairs
        language_pair1
        language_pair2
        LanguagePairFixedPrice.recalculate_prices
        expect(language_pair1.reload.actual_price).to eq 0.12
        expect(language_pair2.reload.actual_price).to eq 0.15
      end
    end

    describe '#recalculate_price' do
      it 'recalculates the price' do
        language_pair1.recalculate_price
        expect(language_pair1.reload.actual_price).to eq 0.12
      end
    end
  end

  describe '.create_pairs_for_new_language' do
    before(:each) do
      # Trigger lazy creation of two language pairs required for calculating
      # the average price of the new language pairs created in the following
      # tests. This will also create 2 languages.
      language_pair1
      language_pair2
    end

    it 'creates all possible pairs for a new language and calculates their prices' do
      expect do
        # When creating a new language, language pairs are automatically
        # created. Two language pairs for each existing language + 1 pair where
        # the new language is both language_from and language_to (for proof
        # reading jobs). There are 2 preexisting languages.
        FactoryGirl.create(:german_language,
                           skip_language_pairs_creation: false)
      end.to change(LanguagePairFixedPrice, :count).by(5)
    end

    it 'calculates the prices for the new language pairs' do
      new_language = FactoryGirl.create(:german_language,
                                        skip_language_pairs_creation: false)
      # One of the 5 new pairs generated when the new language was created
      new_pair = LanguagePairFixedPrice.where(
        from_language: new_language,
        to_language: language_pair1.to_language
      ).first
      # The new language pair has a preexisting language as to_language. Its
      # price should be the average of all preexisting language pairs which
      # have that preexisting language as to_language.
      expect(new_pair.actual_price).to eq(language_pair1.actual_price)
    end
  end
end
