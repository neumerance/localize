module TranslationMemoryActions
  class UpsertTranslatedMemory
    def call(cms_request:)
      cms_request.base_xliff.parsed_xliff.xliff_trans_units.each do |tu|
        tu.target_mrks.select { |mrk| mrk.translated_memory.nil? }.each do |mrk|
          update_mrk_tm(mrk, cms_request.website.client, cms_request.cms_target_language.translator)
        end
      end
    end

    private

    def update_mrk_tm(mrk, client, translator)
      update_client_mrk_tm(mrk, client, translator)
      update_or_create_translator_mrk_tm(mrk, translator)
    end

    def update_client_mrk_tm(mrk, client, translator)
      translation_memory = mrk.source_mrk.translation_memory
      translated_memory = translation_memory.translated_memories.where(language_id: mrk.language_id).last
      translated_memory ||= TranslatedMemory.new(translation_memory: translation_memory, client: client, language: mrk.language)
      translated_memory.translator = translator
      translated_memory.content = mrk.content
      translated_memory.raw_content = translated_memory.content.gsub(/<.*?>/, '')
      translated_memory.save!
    end

    def update_or_create_translator_mrk_tm(mrk, translator)
      translators_translation_memory = mrk.source_mrk.translators_translation_memory
      translators_translation_memory ||= CreateTranslatorsTranslationMemory.new.call(mrk, mrk.get_word_count)
      translators_translated_memory = translators_translation_memory.translators_translated_memories.where(language_id: mrk.language_id).last
      translators_translated_memory ||= TranslatorsTranslatedMemory.new(translators_translation_memory: translators_translation_memory, translator_id: translator.id, language: mrk.language)
      translators_translated_memory.content = mrk.content
      translators_translated_memory.raw_content = translators_translated_memory.content.gsub(/<.*?>/, '')
      translators_translated_memory.save!
    end
  end
end
