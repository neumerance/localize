class GlossaryTranslation < ApplicationRecord
  belongs_to :glossary_term
  belongs_to :language

  validates_presence_of :txt, :language_id
end
