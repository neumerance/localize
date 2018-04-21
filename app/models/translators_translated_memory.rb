class TranslatorsTranslatedMemory < ApplicationRecord
  belongs_to :translators_translation_memory
  belongs_to :language
  belongs_to :client
  belongs_to :translator
  has_many :xliff_trans_unit_mrks
end
