module Glossary
  def set_glossary_edit(client, orig_language, translation_languages)
    @glossary_client = client
    @glossary_orig_language = orig_language
    @glossary_languages = translation_languages

    if @user[:type] == 'Translator'
      session[:glossary_clients] = {} unless session[:glossary_clients]
      session[:glossary_clients][client.id] = [orig_language, translation_languages]
    elsif @user == client
      session[:glossary_orig_language] = @glossary_orig_language
      session[:glossary_languages] = @glossary_languages
    end

    # build the glossary
    @glossary = {}
    @glossary_client.
      glossary_translations.
      joins(:glossary_term).
      where(
        '(glossary_terms.txt IS NOT NULL) AND (glossary_translations.txt IS NOT NULL) AND (glossary_terms.language_id=?) AND (glossary_translations.language_id IN (?))',
        orig_language.id,
        translation_languages.collect(&:id)
      ).each do |translation|

      term = translation.glossary_term
      dtxt = term.txt.downcase
      @glossary[dtxt] = [term.id, {}] unless @glossary.key?(dtxt)
      @glossary[dtxt][1][term.description] = {} unless @glossary[dtxt][1].key?(term.description)
      @glossary[dtxt][1][term.description][translation.language.name] = translation.txt
    end
  end
end
