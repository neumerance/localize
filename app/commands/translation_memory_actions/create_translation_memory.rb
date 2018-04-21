module TranslationMemoryActions
  class CreateTranslationMemory
    def call(xliff_trans_unit_mrk:, content_word_count:)
      find_or_create_tm(
        xliff_trans_unit_mrk.content,
        xliff_trans_unit_mrk.xliff_trans_unit.parsed_xliff.client_id,
        xliff_trans_unit_mrk.language_id,
        content_word_count
      )
    end

    def find_or_create_tm(content, client_id, language_id, wc)
      sig = IclHelpers::Common.calculate_signature(content)
      tm = TranslationMemory.where(signature: sig, language_id: language_id, client_id: client_id).first
      unless tm
        tm = TranslationMemory.new
        tm.client_id = client_id
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
