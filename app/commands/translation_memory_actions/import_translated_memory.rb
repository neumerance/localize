module TranslationMemoryActions
  class ImportTranslatedMemory
    def call(xliff_trans_unit:)
      xliff_trans_unit.target_mrks.each do |target_mrk|
        source = target_mrk.source_mrk
        target_mrk.translation_memory = source.translation_memory
        tm = source.translation_memory.translated_memories.where(language: xliff_trans_unit.target_language).first
        # For example translating Google to Chinese, should be 1 word not 6
        target_mrk.update_attributes(word_count: source.word_count) if source.content == target_mrk.content
        if tm
          next if tm.tm_status == TranslatedMemory::TM_SOURCE[:from_translator] || target_mrk.mrk_status < tm.tm_status
        else
          next if target_mrk.mrk_status == TranslatedMemory::TM_SOURCE[:imported_error]
          tm = TranslatedMemory.new
        end
        tm.client_id = target_mrk.client_id
        tm.language_id = target_mrk.language_id
        tm.translation_memory_id = source.translation_memory_id
        tm.translator_id = source.cms_request.cms_target_language.translator_id
        tm.content = target_mrk.content.strip
        tm.raw_content = IclHelpers::Common.raw(tm.content)
        tm.tm_status = target_mrk.mrk_status
        tm.save!
      end
    end
  end
end
