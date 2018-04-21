module CmsActions
  module Parsing
    class CreateXliffMrkFromXml
      def call(xml:, type:, xliff_trans_unit:, language:)
        xtum = XliffTransUnitMrk.new
        xtum.xliff_trans_unit = xliff_trans_unit
        xtum.trans_unit_id = xliff_trans_unit.trans_unit_id
        xtum.language = language
        xtum.mrk_type = type
        xtum.top_content = xml.to_s.split('>').first.concat('>')
        xtum.mrk_id = xml.attributes['mid'].text.to_i
        xtum.mrk_status = xml.attributes['mstatus'].text.to_i
        content = xml.to_s.sub(xtum.top_content, '').sub(xtum.bottom_content, '')
        xtum.content = content.strip.tr("\n", ' ')
        content_word_count = xtum.get_word_count
        xtum.word_count = content_word_count
        xtum.tm_word_count = content_word_count
        if type == XliffTransUnitMrk::MRK_TYPES[:source]
          xtum.translation_memory = TranslationMemoryActions::CreateTranslationMemory.new.call(
            xliff_trans_unit_mrk: xtum, content_word_count: content_word_count
          )
        end
        xtum.xliff = xtum.xliff_trans_unit.parsed_xliff.xliff
        xtum.cms_request = xtum.xliff_trans_unit.parsed_xliff.cms_request
        xtum.client = xtum.xliff_trans_unit.parsed_xliff.cms_request.website.client
        xtum.save!
      end
    end
  end
end
