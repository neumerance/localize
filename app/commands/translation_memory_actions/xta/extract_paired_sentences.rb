module TranslationMemoryActions
  module Xta
    class ExtractPairedSentences
      def initialize(xta_content)
        @xta_content = xta_content
      end

      def call
        tms = tms_from_sentences(sentences_from_xta)
        sentences = process(tms)
        StripTags.new.call!(sentences)
        sentences
      end

      private

      def sentences_from_xta
        xta_doc.css('ta_sentence')
      end

      def normalize_space(s)
        s.chars.map { |c| c.ord == 160 ? ' ' : c }.join
      end

      def tms_from_sentences(sentences)
        tms = []
        sentences.each do |sentence|
          tm = {}
          tm[:original] = {}
          tm[:translated] = {}
          hash_sentence = Hash.from_xml(sentence.to_xml)['ta_sentence']
          marker_def = hash_sentence['marker_def']
          marker_def = [marker_def] if marker_def.is_a? Hash
          original_language = hash_sentence['original_language']
          sentence.xpath('text_data').each do |s|
            defined_markers = Hash.from_xml(s.to_xml)['text_data']['marker']
            defined_markers = [defined_markers] if defined_markers.is_a? Hash
            temp_tm = {}
            text = s.xpath('text').text
            language = s.attribute('language').to_s
            temp_tm[:raw_text] = text
            temp_tm[:language] = language
            markers = []
            unless defined_markers.nil?
              defined_markers.each do |dm|
                marker_def.each do |md|
                  next unless dm['id'] == md['id']
                  start_html_marker = "<#{md['html_marker']['tag']}"
                  end_html_marker = "</#{md['html_marker']['tag']}>"
                  if md['html_marker']['attr'].is_a? Hash
                    start_html_marker << " #{md['html_marker']['attr']['name']}=\"#{md['html_marker']['attr']['val']}\">"
                  end
                  if md['html_marker']['attr'].is_a? Array
                    md['html_marker']['attr'].each do |mark|
                      start_html_marker << " #{mark['name']}=\"#{mark['val']}\""
                    end
                    start_html_marker << '>'
                  end
                  start_html_marker << '>' if md['html_marker']['attr'].nil?
                  marker = {
                    tag: md['html_marker']['tag'],
                    id: dm['id'],
                    start: dm['start'],
                    end: dm['end'],
                    start_text: start_html_marker,
                    end_text: end_html_marker
                  }
                  markers << marker
                end
              end
            end
            temp_tm[:markers] = markers

            if language == original_language
              tm[:original] = temp_tm
            else
              tm[:translated] = temp_tm
            end

          end
          tms << tm if tm[:original][:raw_text].present? || tm[:translated][:raw_text].present?
        end
        tms
      end

      def process(tms)
        tms.map do |tm|
          {
            original: normalize_space(apply_markers(tm[:original])),
            translated: normalize_space(apply_markers(tm[:translated]))
          }
        end
      end

      def apply_markers(tm)
        return tm[:raw_text] if tm[:markers].blank?
        html_text = ''
        @sorted_markers = sort_markers(tm[:markers])
        raw_text = tm[:raw_text].split('')
        raw_text.each_with_index do |c, i|
          markers_to_be_applied = @sorted_markers.select { |m| m[:position].to_i == i }.sort { |a, b| a[:order] <=> b[:order] }
          markers_to_be_applied.each do |m|
            html_text << m[:tag]
          end
          html_text << c
          next unless i == raw_text.size - 1
          markers_to_be_applied = @sorted_markers.select { |m| m[:position].to_i == i + 1 }.sort { |a, b| a[:order] <=> b[:order] }
          markers_to_be_applied.each do |m|
            html_text << m[:tag]
          end
        end

        convert_to_gx(html_text)
      end

      def convert_to_gx(html)
        doc = Otgs::Segmenter::Utils::Nodes.build_html_root(html)
        root = doc.css(Otgs::Segmenter::Utils::Nodes::ROOT_TAG).first
        global_index = { value: 0 }

        converted_nodes = root.children.map do |ch|
          Otgs::Segmenter::GxTags::Converter.new.convert(ch, global_index)
        end

        converted_html = converted_nodes.join

        doc = Otgs::Segmenter::Utils::Nodes.build_html_root(converted_html)
        root = doc.css(Otgs::Segmenter::Utils::Nodes::ROOT_TAG).first
        root.children.map(&:to_xhtml).join
      end

      def sort_markers(arr)
        arr = arr.map(&:symbolize_keys)
        arr.each do |h|
          h[:start] = h[:start].to_i
          h[:end] = h[:end].to_i
          h[:end] = 10000 if h[:end] < 0
        end
        position_keys = arr.collect { |x| [x[:start], x[:end]] }.flatten.uniq.sort
        tags = []
        ctr = 0
        position_keys.each do |position|
          close_items = arr.select { |x| x[:end] == position }.sort_by { |_x| [:start] }.reverse
          close_items.each do |item|
            ctr += 1
            tags << { order: ctr, position: item[:end], tag: item[:end_text] }
          end
          start_items = arr.select { |x| x[:start] == position }.sort_by { |_x| [:end] }
          start_items.each do |item|
            ctr += 1
            tags << { order: ctr, position: item[:start], tag: item[:start_text] }
          end
        end
        tags.sort_by { |x| [x[:position], x[:order]] }
      end

      def xta_doc
        @xta_doc ||= Nokogiri::XML.parse(@xta_content)
      end
    end
  end
end
