module TranslationMemoryActions
  class CreateTranslatorsTranslationMemory
    def call(xliff_trans_unit_mrk, content_word_count)
      find_or_create_tm(
        xliff_trans_unit_mrk.content,
        xliff_trans_unit_mrk.xliff_trans_unit.parsed_xliff.cms_request.translator.id,
        xliff_trans_unit_mrk.language_id,
        content_word_count
      )
    end

    def find_or_create_tm(content, translator_id, language_id, wc)
      sig = IclHelpers::Common.calculate_signature(content)
      tm = TranslatorsTranslationMemory.where(signature: sig, language_id: language_id, translator_id: translator_id).first
      unless tm
        tm = TranslatorsTranslationMemory.new
        tm.translator_id = translator_id
        tm.language_id = language_id
        tm.signature = sig
        tm.content = content.strip
        tm.raw_content = IclHelpers::Common.raw(content)
        tm.raw_signature = IclHelpers::Common.calculate_signature(tm.raw_content)
        tm.word_count = wc
        tm.save!
      end
      tm
    end
  end
end
