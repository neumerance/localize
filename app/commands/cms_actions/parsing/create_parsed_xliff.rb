module CmsActions
  module Parsing
    class CreateParsedXliff
      def call(xliff_id:, force_import: false)
        xliff = Xliff.find(xliff_id)
        # make sure that a cms_reuqest has only one parsed_xliff
        clean_up_old(xliff.cms_request.id) unless xliff.cms_request.xliff_processed?
        px = ParsedXliff.new
        if force_import || xliff.translated # we should assign base_xliff, not translated one
          bx = xliff.cms_request.base_xliff
          px.xliff = bx
        else
          px.xliff = xliff
        end
        px.cms_request = xliff.cms_request
        px.website = xliff.cms_request.website
        px.client = xliff.cms_request.website.client
        px.source_language = xliff.cms_request.language
        px.target_language = xliff.cms_request.cms_target_language.language

        process_and_set_xliff(px, xliff.get_contents, force_import)

        word_count = 0
        tm_word_count = 0
        px.xliff_trans_units.each do |trans_unit|
          trans_unit.xliff_trans_unit_mrks.each do |mrk|
            next if mrk.mrk_type == XliffTransUnitMrk::MRK_TYPES[:target]
            word_count += mrk.word_count
            tm_word_count += mrk.tm_word_count
          end
        end
        px.update_attributes!(word_count: word_count, tm_word_count: tm_word_count)
        if force_import || xliff.translated # we want to update base_xliff not translated_xliff
          bx = xliff.cms_request.base_xliff
          bx.update_attribute(:processed, true) if bx.present?
        else
          xliff.update_attribute(:processed, true)
        end
        xliff.cms_request.update_attributes(xliff_processed: true)
        px
      end

      private

      def clean_up_old(cms_request_id)
        ParsedXliff.where(cms_request_id: cms_request_id).destroy_all
      end

      def process_and_set_xliff(parsed_xliff, raw_xliff_content, force_import)
        raw_parsed = Otgs::Segmenter.parsed_xliff(raw_xliff_content, ignore_targets: !force_import)
        xml = Nokogiri::XML(raw_parsed)
        parsed_xliff.top_content = raw_parsed.split('<header>').first.to_s.gsub(/(?<=>)$\s+/, '')
        parsed_xliff.bottom_content = raw_parsed.split('</body>').last.to_s.gsub(/(?<=>)$\s+/, '')
        parsed_xliff.header = xml.css('header').to_s.gsub(/(?<=>)$\s+/, '')
        parsed_xliff.save!
        xml.css('body').children.each do |tr|
          CreateXliffTransUnit.new.call(xml_unit: tr, parsed_xliff: parsed_xliff, force_import: force_import)
        end
      end
    end
  end
end
