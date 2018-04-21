class TranslatedMemory < ApplicationRecord

  belongs_to :translation_memory
  belongs_to :language
  belongs_to :client
  belongs_to :translator
  has_many :xliff_trans_unit_mrks

  TM_SOURCE = {
    from_translator: 0,
    imported_success: -1,
    imported_problems: -2,
    imported_error: -3
  }.freeze

  # removing this to test utf8mb4 encoding. if that will work, will remove it entirely
  # acts_as_encoded :content
end
