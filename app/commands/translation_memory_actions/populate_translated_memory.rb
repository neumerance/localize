module TranslationMemoryActions
  class PopulateTranslatedMemory
    def call(cms_request:)
      records = Queries::CmsRequests::TaTool::ParentRequests.new.call(cms: cms_request)

      versions = records.map { |cms| translated_version(cms) }.compact
      content_items = versions.map(&:get_contents)

      sentence_groups = content_items.map do |content|
        TranslationMemoryActions::Xta::ExtractPairedSentences.new(content).call
      end

      sentences = sentence_groups.flatten(1).select { |sentence| sentence.values.all?(&:present?) }
      attrs = sentences.map { |sentence| convert_to_tm_attrs(cms_request, sentence) }

      tm_records = save(attrs)

      { sentences: sentences, records: tm_records }
    end

    private

    def translated_version(cms)
      return if cms.revision.nil?
      cms.revision.versions.select { |v| v.user&.type == 'Translator' }.last
    end

    def save(attrs)
      records = { originals: [], translations: [] }

      attrs.each do |attr_item|
        tmo = TranslationMemory.find_or_create_by(attr_item[:original])

        tmt = tmo.translated_memories.find_by(
          client_id: tmo.client_id, language_id: attr_item[:original][:language_id]
        )

        next if tmt.present?

        tmt = tmo.translated_memories.create!(
          client_id: tmo.client_id, language_id: attr_item[:translated][:language_id]
        )

        tmt.update_attributes!(attr_item[:translated])
        records[:originals] << tmo
        records[:translations] << tmt
      end

      records
    end

    def convert_to_tm_attrs(cms, sentence)
      translation_memory_attrs = translation_attrs(cms, sentence[:original].strip)
      translated_memory_attrs = translated_attrs(cms, sentence[:translated].strip)
      {
        original: translation_memory_attrs,
        translated: translated_memory_attrs
      }
    end

    def translation_attrs(cms, content)
      raw_content = IclHelpers::Common.raw(content)

      {
        client_id: cms.website.client_id,
        language_id: cms.language_id,
        content: content,
        raw_content: raw_content,
        signature: IclHelpers::Common.calculate_signature(content),
        raw_signature: IclHelpers::Common.calculate_signature(raw_content),
        word_count: Processors::WordCounter.count(content, cms.language.count_method, cms.language.ratio)
      }
    end

    def translated_attrs(cms, content)
      raw_content = IclHelpers::Common.raw(content)

      {
        client_id: cms.website.client_id,
        language_id: cms.cms_target_language.language_id,
        content: content,
        raw_content: raw_content,
        tm_status: TranslatedMemory::TM_SOURCE[:imported_success]
      }
    end
  end
end
