class Document < ApplicationRecord
  belongs_to :owner, polymorphic: true
  has_many :db_content_translations, as: :owner

  validates :body, length: { maximum: COMMON_NOTE }

  def i18n_txt(locale_language)
    translation = nil
    if locale_language
      translation = db_content_translations.where('db_content_translations.language_id=?', locale_language.id).first
    end
    translation ? translation.txt : body
  end
end
