class KeywordTranslation < ApplicationRecord
  belongs_to :keyword

  TRANSLATION = 0
  ALTERNATIVE = 1
end
