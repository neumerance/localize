require 'rails_helper'

describe WebsiteTranslationOffer do
  context 'validations' do
    shared_examples 'has_base_validation_error' do
      it 'has validation error' do
        website_translation_offer.valid?
        expect(website_translation_offer.errors[field].first).to eq(message)
      end
    end

    context 'presence' do
      %w(from_language_id to_language_id).each do |field|
        let(:website_translation_offer) { build(:website_translation_offer, field.to_sym => 0) }
        let(:message) { 'must be specified' }
        let(:field) { field.to_sym }
        include_examples 'has_base_validation_error'
      end
    end

    context 'language from and to ' do
      let(:website_translation_offer) { build(:website_translation_offer, from_language_id: 1, to_language_id: 1) }
      let(:message) { 'From and to languages must be different' }
      let(:field) { :base }
      include_examples 'has_base_validation_error'
    end
  end

  describe 'language pair statistics' do
    before(:each) do
      # Clear the test DB
      # As long as config.use_transactional_fixtures = true, this deletion is
      # executed within a transaction and rolled back after each test. That
      # means other specs which rely on preexisting records in the test DB will
      # not be affected.
      LanguagePairFixedPrice.delete_all
      Language.delete_all
      CmsRequest.delete_all
      WebsiteTranslationOffer.delete_all
      WebsiteTranslationContract.delete_all
      ManagedWork.delete_all
    end

    let(:website) { FactoryGirl.create(:website, api_version: '2.0') }

    let(:english) do
      FactoryGirl.create(:english_language, skip_language_pairs_creation: true)
    end

    let(:german) do
      FactoryGirl.create(:german_language, skip_language_pairs_creation: true)
    end

    let(:french) do
      FactoryGirl.create(:french_language, skip_language_pairs_creation: true)
    end

    let!(:english_german) do
      FactoryGirl.create(:language_pair_fixed_price,
                         from_language: english,
                         to_language: german,
                         actual_price: 0.11,
                         published: true)
    end

    let!(:english_french) do
      FactoryGirl.create(:language_pair_fixed_price,
                         from_language: english,
                         to_language: french,
                         actual_price: 0.11,
                         published: true)
    end

    let!(:website_translation_offer) do
      # This factory creates a managed_work by default
      FactoryGirl.create(:website_translation_offer,
                         website: website,
                         from_language: english,
                         to_language: german,
                         automatic_translator_assignment: true)
    end

    let!(:website_translation_contract) do
      FactoryGirl.create(:website_translation_contract,
                         website_translation_offer: website_translation_offer,
                         status: TRANSLATION_CONTRACT_ACCEPTED,
                         amount: 0.10)
    end

    # Translation review
    let!(:managed_work) do
      managed_work = website_translation_offer.managed_work
      managed_work.update(
        from_language: english,
        to_language: german,
        translator: FactoryGirl.create(:translator),
        active: MANAGED_WORK_ACTIVE
      )
      managed_work
    end

    let!(:pending_cms_request1) do
      FactoryGirl.create(
        :cms_request,
        website: website,
        # Source language
        language: english,
        deadline: 1.day.from_now,
        word_count: 10,
        cms_target_language: FactoryGirl.create(
          :cms_target_language,
          language: german,
          word_count: 10,
          # Not yed funded
          status: CMS_TARGET_LANGUAGE_CREATED
        )
      )
    end

    let!(:pending_cms_request2) do
      FactoryGirl.create(
        :cms_request,
        website: website,
        # Source language
        language: english,
        deadline: 3.days.from_now,
        word_count: 100,
        cms_target_language: FactoryGirl.create(
          :cms_target_language,
          language: german,
          word_count: 100,
          # Not yed funded
          status: CMS_TARGET_LANGUAGE_CREATED
        )
      )
    end

    let!(:pending_cms_request3) do
      FactoryGirl.create(
        :cms_request,
        website: website,
        # Source language
        language: english,
        deadline: 5.days.from_now,
        word_count: 1000,
        cms_target_language: FactoryGirl.create(
          :cms_target_language,
          language: french,
          word_count: 1000,
          # This one is funded
          status: CMS_TARGET_LANGUAGE_ASSIGNED
        )
      )
    end

    let!(:funded_cms_request1) do
      FactoryGirl.create(
        :cms_request,
        website: website,
        # Source language
        language: english,
        deadline: 3.days.from_now,
        word_count: 100,
        cms_target_language: FactoryGirl.create(
          :cms_target_language,
          language: german,
          word_count: 100,
          # Funded
          status: CMS_TARGET_LANGUAGE_ASSIGNED
        )
      )
    end

    describe '.cms_requests' do
      it 'returns all cms_requests for this language pair and website' do
        expect(website_translation_offer.cms_requests).to \
          include(pending_cms_request1, pending_cms_request2, funded_cms_request1)
      end

      it 'does not return cms_requests of other language pairs' do
        expect(website_translation_offer.cms_requests).not_to \
          include(pending_cms_request3)
      end
    end

    describe '.all_pending_cms_requests' do
      it 'returns pending cms_requests for this language pair and website' do
        expect(website_translation_offer.all_pending_cms_requests).to \
          include(pending_cms_request1, pending_cms_request2)
      end

      it 'does not return funded cms_requests' do
        expect(website_translation_offer.all_pending_cms_requests).not_to \
          include(funded_cms_request1)
      end
    end

    describe '#word_count' do
      it 'returns the correct word count for all pending cms_requests' do
        expect(website_translation_offer.word_count).to eq 110
      end
    end

    describe '#price_per_word' do
      context 'with automatic translator assignment' do
        it 'includes the correct price per word (including the review)' do
          expect(website_translation_offer.total_price_per_word).to eq(0.11)
        end
      end

      context 'with manual translator assignment' do
        it 'includes the correct price per word (including the review)' do
          website_translation_offer.disable_automatic_translator_assignment!
          expect(website_translation_offer.total_price_per_word).to eq(0.10)
        end
      end
    end

    describe '#total_price' do
      context 'with automatic translator assignment' do
        it 'returns the total price for all words including the review' do
          # RSpec was converting the total_price from BigDecimal to Float,
          # which was generating precision issues.
          expect(website_translation_offer.total_price.round(2)).to eq(110 * 0.11)
        end
      end

      context 'with manual translator assignment' do
        it 'returns the total price for all words including the review' do
          website_translation_offer.disable_automatic_translator_assignment!
          # RSpec was converting the total_price from BigDecimal to Float,
          # which was generating precision issues.
          expect(website_translation_offer.total_price.round(2)).to eq(12.1)
        end
      end
    end

    describe '#estimated_completion_date' do
      it 'includes the correct estimated completion date (deadline)' do
        # Strip seconds from the expected date as they make flaky tests (de data
        # can be created in the end of a second and the test executed in the
        # beginning of the following second).
        db_hours_and_minutes = website_translation_offer.estimated_completion_date.strftime('%H:%M')
        expect(db_hours_and_minutes).to eq(3.days.from_now.strftime('%H:%M'))
      end
    end

  end

  describe '#automatic_translator_assignment_usage_report' do
    before(:each) do
      LanguagePairFixedPrice.delete_all
      Language.delete_all
      CmsRequest.delete_all
      WebsiteTranslationOffer.delete_all
      WebsiteTranslationContract.delete_all
      ManagedWork.delete_all
    end

    let(:english) do
      FactoryGirl.create(:english_language, skip_language_pairs_creation: true)
    end

    let(:german) do
      FactoryGirl.create(:german_language, skip_language_pairs_creation: true)
    end

    let(:french) do
      FactoryGirl.create(:french_language, skip_language_pairs_creation: true)
    end

    let!(:english_german) do
      FactoryGirl.create(:language_pair_fixed_price,
                         from_language: english,
                         to_language: german,
                         actual_price: 0.11,
                         published: true)
    end

    let!(:english_french) do
      FactoryGirl.create(:language_pair_fixed_price,
                         from_language: english,
                         to_language: french,
                         actual_price: 0.11,
                         published: true)
    end

    1.upto(10) do |i|
      let!("website#{i}".to_sym) { FactoryGirl.create(:website, name: "Website Project #{i}", api_version: '2.0') }
    end

    let!(:english_to_german_wtos) do
      [].tap do |wtos|
        1.upto(3) do |i|
          wtos << FactoryGirl.create(:website_translation_offer, website: send("website#{i}"), from_language: english, to_language: german, automatic_translator_assignment: true)
        end
      end
    end

    let!(:english_to_french_wtos) do
      [].tap do |wtos|
        4.upto(7) do |i|
          wtos << FactoryGirl.create(:website_translation_offer, website: send("website#{i}"), from_language: english, to_language: french, automatic_translator_assignment: true)
        end
      end
    end

    let!(:wto_not_automatic) do
      [].tap do |wtos|
        8.upto(10) do |i|
          wto = FactoryGirl.create(:website_translation_offer, website: send("website#{i}"), from_language: english, to_language: [german, french].sample)
          # factory girl is overriding `automatic_translator_assignment` to `true`
          # so needed to force it to be false
          wto.update(automatic_translator_assignment: 0)
          wto.reload
          wtos << wto
        end
      end
    end

    let!(:eng_ger_cms_requests) do
      [].tap do |cms_requests|
        english_to_german_wtos.each do |wto|
          cms_requests << FactoryGirl.create(
            :cms_request,
            website: wto.website,
            language: english,
            deadline: 3.days.from_now,
            word_count: 100,
            cms_target_language: FactoryGirl.create(
              :cms_target_language,
              language: german,
              word_count: 100,
              status: CMS_TARGET_LANGUAGE_ASSIGNED
            ),
            pending_money_transaction: FactoryGirl.create(:pending_money_transaction)
          )
        end
      end
    end

    let!(:eng_french_cms_requests) do
      [].tap do |cms_requests|
        english_to_french_wtos.each do |wto|
          cms_requests << FactoryGirl.create(
            :cms_request,
            website: wto.website,
            language: english,
            deadline: 4.days.from_now,
            word_count: 200,
            cms_target_language: FactoryGirl.create(
              :cms_target_language,
              language: french,
              word_count: 200,
              status: CMS_TARGET_LANGUAGE_ASSIGNED
            ),
            pending_money_transaction: FactoryGirl.create(:pending_money_transaction)
          )
        end
      end
    end

    let!(:cms_requests_not_auto_assigned) do
      [].tap do |cms_requests|
        wto_not_automatic.each do |wto|
          cms_requests << FactoryGirl.create(
            :cms_request,
            website: wto.website,
            language: english,
            deadline: 4.days.from_now,
            word_count: 200,
            cms_target_language: FactoryGirl.create(
              :cms_target_language,
              language: french,
              word_count: 200,
              status: CMS_TARGET_LANGUAGE_ASSIGNED
            ),
            pending_money_transaction: FactoryGirl.create(:pending_money_transaction)
          )
        end
      end
    end

    describe 'Automatic Translator Assignment total' do
      it do
        automatic_translator_assignment = WebsiteTranslationOffer.automatic_translator_assignment_usage_report[0]
        accepted_websites_count = (english_to_german_wtos.size + english_to_french_wtos.size)
        expect(automatic_translator_assignment.total_count).to eq(wto_not_automatic.size + accepted_websites_count)
        expect(automatic_translator_assignment.accepted_count).to eq(accepted_websites_count)
      end
    end

    describe 'Automatic Translator Assignment usage per language total' do
      it do
        automatic_translator_assignment = WebsiteTranslationOffer.automatic_translator_assignment_usage_report(per_language: true)
        german_non_auto_wtos = WebsiteTranslationOffer.where(to_language_id: german.id, automatic_translator_assignment: false)
        french_non_auto_wtos = WebsiteTranslationOffer.where(to_language_id: french.id, automatic_translator_assignment: false)
        eng_to_german_assignment = automatic_translator_assignment.select { |x| x.source_language_name == 'English' && x.target_language_name == 'German' }[0]
        eng_to_french_assignment = automatic_translator_assignment.select { |x| x.source_language_name == 'English' && x.target_language_name == 'French' }[0]
        expect(eng_to_german_assignment.accepted_count).to eq(english_to_german_wtos.size)
        expect(eng_to_german_assignment.total_count).to eq(english_to_german_wtos.size + german_non_auto_wtos.size)
        expect(eng_to_french_assignment.accepted_count).to eq(english_to_french_wtos.size)
        expect(eng_to_french_assignment.total_count).to eq(english_to_french_wtos.size + french_non_auto_wtos.size)
      end
    end
  end
end
