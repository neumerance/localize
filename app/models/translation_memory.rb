class TranslationMemory < ApplicationRecord
  belongs_to :client
  belongs_to :language
  has_many :translated_memories
  has_many :xliff_trans_unit_mrks
end
