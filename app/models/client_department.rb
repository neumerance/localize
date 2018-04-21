class ClientDepartment < ApplicationRecord
  belongs_to :web_support
  belongs_to :language
  has_many :web_dialogs, dependent: :destroy
  has_many :db_content_translations, as: :owner, dependent: :destroy

  validates_presence_of :name, :language_id, :translation_status_on_create

  validate :validate_language_id, on: :create

  include TranslateableObject

  def validate_language_id
    errors.add(:language_id, _('not selected')) if language_id == 0
  end

  def translated_name(language)
    if language
      translation = db_content_translations.where(language_id: language.id).first
      return translation.txt if translation && !translation.txt.blank?
    end
    name
  end

end
