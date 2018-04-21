module TranslationMemoryImporter
  class Checker

    def initialize(cms)
      @cms = cms
      @logger = Logger.new('log/chcker.log')
    end

    def compare_with_xliff(tms)
      original_count, translated_count, total = parse_translated
      @logger.info("#{@cms.id},#{original_count},#{translated_count},#{total},#{tms.select { |o| o[:original].present? }.size},#{tms.select { |t| t[:translated].present? }.size}, #{tms.size}")
    end

    def compare_sentences(from_remote = true)
      translated_xta = @cms.revision.versions.last
      xta_content = FileFetcher.new(translated_xta.full_filename, translated_xta.filename, from_remote).fetch
      translated_xliff = @cms.translated_xliff
      xliff_content = FileFetcher.new(translated_xliff.full_filename, translated_xliff.filename, from_remote).fetch
      tms = XtaParser.new(xta_content).prepare_tms
      xml = Nokogiri::XML(Otgs::Segmenter::HTMLExtractor.new(xliff_content).get_parsed_xliff)

      comp_holder = {}
      comp_holder[:xta] = []
      comp_holder[:xliff] = []
      tms.each do |tm|
        comp_holder[:xta] << {
          o_raw: tm[:original][:raw_text],
          o_xliff: tm[:original][:xliff_text],
          t_raw: tm[:translated][:raw_text],
          t_xliff: tm[:translated][:xliff_text]
        }
      end
      xml.css('seg-source mrk').each do |s|
        xml.css('target mrk').each do |t|
          next unless t.attribute('mid').value == s.attribute('mid').value
          comp_holder[:xliff] << {
            o_raw: s.text,
            o_xliff: s.text,
            t_raw: t.text,
            t_xliff: t.text
          }
        end
      end
      comp = File.open('comp.csv', 'wb')
      0.upto([comp_holder[:xta].size, comp_holder[:xliff].size].max) do |_i|
        comp.puts("#{comp_holder[:xta][:i][:o_raw]},#{comp_holder[:xta][:i][:o_xliff]},#{comp_holder[:xta][:i][:t_raw]},#{comp_holder[:xta][:i][:t_xliff]},#{comp_holder[:xliff][:i][:o_raw]},#{comp_holder[:xliff][:i][:o_xliff]},#{comp_holder[:xliff][:i][:t_raw]},#{comp_holder[:xliff][:i][:t_xliff]}")
      end
    end

    def parse_translated
      raw_xliff_content = @cms.translated_xliff.get_contents
      raw_parsed = Otgs::Segmenter::HTMLExtractor.new(raw_xliff_content).get_parsed_xliff
      xml = Nokogiri::XML(raw_parsed)
      [xml.css('seg-source mrk').size, xml.css('target mrk').size, xml.css('mrk').size]
    end

  end
end
