class TranslatorsTranslationMemory < ApplicationRecord
  belongs_to :translator
  belongs_to :language
  has_many :translators_translated_memories
  has_many :xliff_trans_unit_mrks
end
