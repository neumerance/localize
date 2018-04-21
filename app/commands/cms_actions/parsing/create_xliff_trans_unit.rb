module CmsActions
  module Parsing
    class CreateXliffTransUnit
      def call(xml_unit:, parsed_xliff:, force_import: false)
        xtr = XliffTransUnit.new
        xtr.parsed_xliff = parsed_xliff
        xtr.source_language = parsed_xliff.source_language
        xtr.target_language = parsed_xliff.target_language
        xtr.trans_unit_id = xml_unit.attributes['id']
        xtr.source = xml_unit.css('source').to_s
        xtr.top_content = xml_unit.to_s.split('<source').first
        xtr.bottom_content = "\n</trans-unit>"
        xtr.save!

        xml_unit.css('seg-source').children.each do |mrk_xml|
          next unless mrk_xml.is_a? Nokogiri::XML::Element
          CreateXliffMrkFromXml.new.call(xml: mrk_xml, type: XliffTransUnitMrk::MRK_TYPES[:source],
                                         xliff_trans_unit: xtr, language: xtr.source_language)
        end

        xml_unit.css('target').children.each do |mrk_xml|
          next unless mrk_xml.is_a? Nokogiri::XML::Element
          CreateXliffMrkFromXml.new.call(xml: mrk_xml, type: XliffTransUnitMrk::MRK_TYPES[:target],
                                         xliff_trans_unit: xtr, language: xtr.target_language)
        end

        pair_up_mrks(xtr)

        if force_import
          TranslationMemoryActions::ImportTranslatedMemory.new.call(xliff_trans_unit: xtr)
        else
          TranslationMemoryActions::ApplyTranslatedMemory.new.call(xliff_trans_unit: xtr)
        end

        FixTransUnitStatus.new.call(xliff_trans_unit: xtr, force_import: force_import)
      end

      private

      def pair_up_mrks(xtr)
        xtr.source_mrks.each do |source_mrk|
          target_mrk = xtr.target_mrks.where(source_id: nil, translated_memory_id: source_mrk.translated_memory_id).first
          target_mrk = CreateXliffTargetMrk.new.call(source_mrk: source_mrk) unless target_mrk.present?
          source_mrk.update_attributes(target_id: target_mrk.id)
          target_mrk.update_attributes(source_id: source_mrk.id)
        end
      end
    end
  end
end
