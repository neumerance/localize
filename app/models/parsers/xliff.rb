require 'xliffer'

class Parsers::Xliff

  class << self

    def parse(decoded_src)
      resource_strings = []

      xliff = build_xliff(decoded_src)

      xliff.files.each do |file|
        file.strings.each do |string|
          resource_strings << {
            comments: string.note,
            token: "#{file.original}##{string.id}",
            text: string.source,
            translation: string.target
          }
        end
      end
      resource_strings
    end

    def merge(contents, string_translations, languages)
      ret = {}
      languages.each do |language|
        xliff = XLIFFer::XLIFF.new contents
        strings = 0
        strings_found = 0

        xliff.files.each do |file|
          file.target_language = language.iso

          file.strings.each do |string|
            strings += 1
            token = "#{file.original}##{string.id}"[0..254]
            if string_translations[[token, language.id]]
              strings_found += 1
              target_string = string_translations[[token, language.id]]
              string.target = normalize_qoutes(target_string)
            else
              Rails.logger.info "String not found for #{language.name}: #{token}"
            end
          end
        end

        # icldev-2151 Nokogiri bug escaping carriage returns
        merged_xliff = xliff.to_s.gsub('&amp;quot;', '&quot;').gsub('&#13;', "\r")
        ret[language] = [merged_xliff, [strings, strings_found]]
      end

      ret
    end

    private

    def build_xliff(decoded_src)
      XLIFFer::XLIFF.new(decoded_src)
    rescue XLIFFer::NoElement => ex
      Logging.log_error(self, ex)
      return OpenStruct.new(files: [])
    end

    def normalize_qoutes(str)
      n = Otgs::Segmenter::Utils::Nodes.build_html_root(str)
      text_nodes = n.search('//text()').to_a.reject(&:cdata?)
      double_qoute_marker = '{{wpml_double_quote}}'

      text_nodes.each do |t|
        t.content = t.text.gsub('"', double_qoute_marker)
      end

      content = n.css('wpml_root').children.map(&:to_xhtml).join
      content.gsub(double_qoute_marker, '&quot;')
    end
  end
end
