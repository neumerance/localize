module TranslationMemoryActions
  class ApplyTranslatedMemory
    def call(xliff_trans_unit:)
      xliff_trans_unit.target_mrks.each do |target_mrk|
        apply_memory_to_mrk!(xliff_trans_unit, target_mrk)
      end
    end

    private

    def apply_memory_to_mrk!(xliff_trans_unit, target_mrk)
      source_mrk = target_mrk.source_mrk
      target_mrk.translation_memory = source_mrk.translation_memory
      translated_memory = source_mrk.translation_memory.translated_memories.where(language: xliff_trans_unit.target_language).last
      website = xliff_trans_unit.parsed_xliff.xliff.cms_request.website

      Rails.logger.info("[#{self.class}][tid=#{target_mrk.id}][before][#{source_mrk.content}][#{translated_memory&.content}]")

      if apply_from_memory?(translated_memory, website, source_mrk)
        Rails.logger.info("[#{self.class}][tid=#{target_mrk.id}][apply]")
        if website.tm_use_mode == TM_COMPLETE_MATCHES
          Rails.logger.info("[#{self.class}][tid=#{target_mrk.id}][apply_completed]")
          apply_completed_tm!(target_mrk, source_mrk, translated_memory)
        else
          Rails.logger.info("[#{self.class}][tid=#{target_mrk.id}][apply_in_progress]")
          apply_in_progress_tm!(target_mrk, translated_memory)
        end
      elsif website_tm_enabled?(website) && translated_memory.present? && same_page?(translated_memory, xliff_trans_unit)
        Rails.logger.info("[#{self.class}][tid=#{target_mrk.id}][same_page][apply_in_progress]")
        apply_in_progress_tm!(target_mrk, translated_memory)
      elsif website_tm_enabled?(website) && translated_memory.nil?
        Rails.logger.info("[#{self.class}][tid=#{target_mrk.id}][apply_raw]")
        apply_raw_tm!(source_mrk, target_mrk)
      end

      sync_top_content_with_status(target_mrk)
      target_mrk.save!
    end

    def apply_completed_tm!(target_mrk, source_mrk, translated_memory)
      target_mrk.content = translated_memory.content
      target_mrk.translated_memory = translated_memory
      target_mrk.tm_word_count = 0
      source_mrk.update_attribute(:tm_word_count, 0)
      target_mrk.update_status(XliffTransUnitMrk::MRK_STATUS[:completed_from_tm])
    end

    def apply_in_progress_tm!(target_mrk, translated_memory)
      target_mrk.content = translated_memory.content
      target_mrk.update_status(XliffTransUnitMrk::MRK_STATUS[:in_progress])
    end

    def apply_raw_tm!(source_mrk, target_mrk)
      signature = IclHelpers::Common.calculate_raw_signature(source_mrk.content)

      tm = TranslationMemory.where(
        raw_signature: signature,
        language_id: source_mrk.language_id,
        client_id: source_mrk.unit.parsed_xliff.client_id
      ).take

      return if tm.nil?
      ttm = tm.translated_memories.where(language_id: target_mrk.language_id).take
      return if ttm.nil?

      target_mrk.content = ttm.raw_content
      target_mrk.update_status(XliffTransUnitMrk::MRK_STATUS[:in_progress])
    end

    def same_page?(translated_memory, current_xliff_unit)
      mrks = translated_memory.translation_memory.xliff_trans_unit_mrks.reject do |x|
        x.cms_request&.id == current_xliff_unit.parsed_xliff.cms_request_id
      end

      cur_cms = current_xliff_unit.parsed_xliff.cms_request

      res = mrks.find do |x|
        mrk_cms = x&.xliff_trans_unit&.parsed_xliff&.cms_request
        mrk_cms&.website_id == cur_cms.website_id && mrk_cms&.cms_id == cur_cms.cms_id
      end

      res.present?
    end

    def website_tm_enabled?(website)
      [TM_COMPLETE_MATCHES, TM_PENDING_MATCHES].include?(website.tm_use_mode)
    end

    def apply_from_memory?(translated_memory, website, source)
      return false if translated_memory.nil?
      tm_use_threshold = website.tm_use_threshold
      website_tm_enabled?(website) && source.word_count >= tm_use_threshold
    end

    def sync_top_content_with_status(target_mrk)
      target_mrk.top_content = target_mrk.top_content.sub(/(?<=mstatus=")-\d/, target_mrk.mrk_status.to_s)
    end
  end
end
