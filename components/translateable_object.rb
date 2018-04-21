module TranslateableObject
  def get_translation(lang_id)
    db_content_translations.where('language_id=?', lang_id).first || name
  end
end
