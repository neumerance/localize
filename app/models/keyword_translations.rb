class KeywordTranslation < ApplicationRecord
  belongs_to :keyword

  TRANSLATION = 0 unless defined? TRANSLATION
  ALTERNATIVE = 1 unless defined? ALTERNATIVE
end
