module CmsActions
  module Parsing
    class CreateXliffTargetMrk
      def call(source_mrk:)
        xtum = XliffTransUnitMrk.new
        xtum.xliff_trans_unit = source_mrk.xliff_trans_unit
        xtum.trans_unit_id = source_mrk.xliff_trans_unit.trans_unit_id
        xtum.language = source_mrk.xliff_trans_unit.target_language
        xtum.mrk_type = XliffTransUnitMrk::MRK_TYPES[:target]
        xtum.top_content = source_mrk.top_content
        xtum.mrk_id = source_mrk.mrk_id
        xtum.mrk_status = source_mrk.mrk_status
        xtum.content = source_mrk.content.strip
        xtum.word_count = source_mrk.word_count
        xtum.tm_word_count = source_mrk.tm_word_count
        xtum.xliff = source_mrk.xliff
        xtum.cms_request = source_mrk.cms_request
        xtum.client = source_mrk.client
        xtum.save!
        xtum
      end
    end
  end
end
