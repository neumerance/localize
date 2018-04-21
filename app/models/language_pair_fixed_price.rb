# Fixed prices for language pairs.
#
# The order of languages (which language is the source and which is the target)
# matters, as prices may be different.
#
# The source (from_language) and target (to_language) languages may be the
# same. This is used for proof reading.
#
# The "calculated_price" attribute stores the calculated price for each language
# pair, which is the average price of all WebsiteTranslationContract records
# with that language pair. "calculated_price_last_year" is the same but it
# only takes into account WebsiteTranslationContract records created in the
# last 12 months.
#
# "number_of_transactions" is the count of WebsiteTranslationContract records
# taken into account when calculating the "calculated_price" of a language
# pair. "number_of_transactions_last_year" is the count of
# WebsiteTranslationContract records taken into account when calculating
# "calculated_price_last_year".
#
# "calculated_price" is not always the fixed price that we want to charge
# from our clients. Hence, we also have the # "actual_price" attribute, which is
# the fixed price that will always be used/applied to the projects.
class LanguagePairFixedPrice < ApplicationRecord
  belongs_to :from_language, class_name: 'Language'
  belongs_to :to_language, class_name: 'Language'

  validates :from_language,
            :to_language,
            :actual_price,
            presence: true
  validates :from_language, uniqueness:
    { scope: :to_language, message: 'and To language pair must be unique.' }
  validates :actual_price, numericality:
    { greater_than_or_equal_to: MINIMUM_FIXED_PRICE, allow_nil: true }

  before_validation :set_calculated_price, :set_actual_price, :ensure_language_pair_id

  def known_language_pair?
    published # supporters will mark the "known" languages
  end

  def translators
    TranslatorLanguagesAutoAssignment.includes(:translator).where(language_pair_id: self.language_pair_id).map do |tla|
      translator = tla.translator.as_json
      translator['translator_language_assignment'] = tla
      translator
    end
  end

  class << self
    def known_language_pair?(from_language, to_language)
      get_language_pair(from_language, to_language).known_language_pair?
    rescue NoMethodError
      false
    end

    def get_language_pair(from_language, to_language)
      where(from_language: from_language, to_language: to_language).first
    end

    def get_price(from_language, to_language)
      get_language_pair(from_language, to_language).actual_price
    end

    def set_price(from_language, to_language, price)
      get_language_pair(from_language, to_language).update(actual_price: price)
    end

    def recalculate_prices(language_pairs = LanguagePairFixedPrice.all)
      if language_pairs.respond_to?(:each)
        language_pairs.each(&:recalculate_price)
      else
        language_pairs.recalculate_price
      end
    end

    # This method is only used to create language pairs and calculate their
    # prices *when a new language is created*. There were approximately 90
    # languages at ICL when this code was written. When a new language is added,
    # approximately 180 new language pairs are automatically created.
    # Calculating their prices based on the average prices of all
    # WebsiteTranslationContract which contains the preexisting language
    # (like #calculate_average_price does) would be too slow. Hence, this method
    # calculates average prices based on existing LanguagePairFixedPrice records
    # that contain the same source or target language (the preexisting language).
    def create_all_pairs_for_new_language(new_language)
      Language.find_each do |existing_language|
        if new_language == existing_language # proof reading language pair
          # A language pair with the same from_language and to_language is used in
          # proof reading jobs. To calculate it's price, we will use the average
          # prices of all existing LanguagePairFixedPrice records
          create_pair_for_new_language(
            from_language: new_language,
            to_language: new_language,
            relevant_language_pairs_for_price_calculation: all
          )
        else # non proof-reading language pairs
          # To calculate the price of a language pair that included a preexisting
          # language and a new language, use the average price of the preexisting
          # language pairs which include the preexisting language.

          # Create language pairs where the new language is the source
          create_pair_for_new_language(
            from_language: existing_language,
            to_language: new_language,
            relevant_language_pairs_for_price_calculation: where(from_language: existing_language)
          )
          # Create language pairs where the new language is the target
          create_pair_for_new_language(
            from_language: new_language,
            to_language: existing_language,
            relevant_language_pairs_for_price_calculation: where(to_language: existing_language)
          )
        end
      end
    end

    private # Does not affect instance methods below the class << self block

    def create_pair_for_new_language(from_language:, to_language:,
                                     relevant_language_pairs_for_price_calculation:)
      create(
        from_language: from_language,
        to_language: to_language,
        calculated_price:
          relevant_language_pairs_for_price_calculation.average(:actual_price),
        number_of_transactions:
          relevant_language_pairs_for_price_calculation.sum(:number_of_transactions),
        calculated_price_last_year:
          relevant_language_pairs_for_price_calculation.average(:calculated_price_last_year),
        number_of_transactions_last_year:
          relevant_language_pairs_for_price_calculation.sum(:number_of_transactions_last_year)
      )
    end
  end # end class methods

  def allow_auto_assign?
    self.published
  end

  def recalculate_price
    calculated_price, number_of_transactions =
      calculate_average_price(last_year_only: false)
    update(
      calculated_price: calculated_price,
      number_of_transactions: number_of_transactions
    )

    calculated_price_last_year, number_of_transactions_last_year =
      calculate_average_price(last_year_only: true)
    update(
      calculated_price_last_year: calculated_price_last_year,
      number_of_transactions_last_year: number_of_transactions_last_year
    )
  end

  # Translators who opted in to be automatically assigned for this language pair
  def auto_assignable_translators
    TranslatorLanguagesAutoAssignment.includes(:translator).where(
      from_language: from_language,
      to_language: to_language
    ).map(&:translator)
  end

  private

  def find_contracts_for_language_pair(last_year_only:)
    contracts =
      WebsiteTranslationContract.includes(:website_translation_offer).where(
        # Translator applied and was accepted by the client
        status: 2,
        website_translation_offers: { from_language_id: from_language_id,
                                      to_language_id: to_language_id }
      )
    contracts = contracts.where(created_at: [12.months.ago..Time.current]) if last_year_only
    contracts
  end

  def calculate_average_price(last_year_only:)
    all_contracts = find_contracts_for_language_pair(last_year_only: last_year_only)
    average_price = all_contracts.average(:amount) || 0
    number_of_transactions = all_contracts.count
    [average_price, number_of_transactions]
  end

  def set_calculated_price
    return if calculated_price.present? && calculated_price > 0
    self.calculated_price, self.number_of_transactions =
      calculate_average_price(last_year_only: false)
    self.calculated_price_last_year, self.number_of_transactions_last_year =
      calculate_average_price(last_year_only: true)
  end

  def set_actual_price
    # If actual_price is greater than calculated_price, it was probably set
    # manually (unless the average price has dropped, which is unlikely).
    # Hence, it should not be changed.
    return if actual_price.present? &&
              actual_price >= calculated_price &&
              actual_price >= MINIMUM_FIXED_PRICE

    self.actual_price = if calculated_price < MINIMUM_FIXED_PRICE
                          MINIMUM_FIXED_PRICE
                        else
                          calculated_price
                        end
  end

  def ensure_language_pair_id
    self.language_pair_id = "#{self.from_language_id}_#{self.to_language_id}"
  end
end
