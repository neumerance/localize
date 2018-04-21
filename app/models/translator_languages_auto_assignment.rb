class TranslatorLanguagesAutoAssignment < ApplicationRecord
  belongs_to :translator
  belongs_to :from_language, class_name: 'Language'
  belongs_to :to_language, class_name: 'Language'

  validates :translator, uniqueness: { scope: [:from_language_id, :to_language_id] }

  validate :validate_min_price_per_word

  attr_writer :autoassign

  before_save :ensure_language_pair_id

  before_create :set_defautl_price

  def autoassign
    persisted? ? true : false
  end

  def price
    if LanguagePairFixedPrice.known_language_pair?(from_language, to_language)
      LanguagePairFixedPrice.get_price(from_language, to_language)
    else
      min_price_per_word
    end
  end

  private

  def ensure_language_pair_id
    self.language_pair_id = "#{self.from_language_id}_#{self.to_language_id}"
  end

  def set_defautl_price
    self.min_price_per_word = LanguagePairFixedPrice.get_price(self.from_language, self.to_language) if self.min_price_per_word.nil?
  end

  def validate_min_price_per_word
    return unless min_price_per_word

    if min_price_per_word < MINIMUM_BID_AMOUNT
      errors.add :min_price_per_word, 'You cannot enter a rate below %.2f USD / word.' % MINIMUM_BID_AMOUNT
    end

    max_rate = MINIMUM_BID_AMOUNT * 10
    if min_price_per_word > max_rate
      errors.add :min_price_per_word, 'You cannot enter a rate above %.2f USD / word.' % max_rate
    end
  end
end
