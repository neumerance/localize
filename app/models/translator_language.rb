class TranslatorLanguage < ApplicationRecord
  belongs_to :translator, touch: true
  belongs_to :language, touch: true
  has_many :translator_language_documents, foreign_key: :owner_id, dependent: :destroy
  has_one :support_ticket, as: :object

  STATUS_TEXT = {
    TRANSLATOR_LANGUAGE_NEW => N_('You must describe your background in this language and upload a document that demonstrates it'),
    TRANSLATOR_LANGUAGE_REQUEST_REVIEW => N_('Pending review by staff member'),
    TRANSLATOR_LANGUAGE_DECLINED => N_('Request denied'),
    TRANSLATOR_LANGUAGE_APPROVED => N_('Translation language approved')
  }.freeze

end
