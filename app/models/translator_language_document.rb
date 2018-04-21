class TranslatorLanguageDocument < UserDocument
  belongs_to :translator_language, foreign_key: :owner_id
  belongs_to :translator, foreign_key: :by_user_id, touch: true
end
