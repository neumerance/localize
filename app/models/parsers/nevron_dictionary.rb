class Parsers::NevronDictionary

  class << self

    def parse(decoded_src)
      parsed_file = Nokogiri::XML(decoded_src)

      parsed_file.xpath('//tu').each_with_object([]) do |node, resource_strings|
        group = node.xpath('prop').text
        original_string = node.xpath('tuv').first.xpath('seg').first.text

        resource_strings << {
          comments: group,
          token: Digest::MD5.hexdigest("#{group}_#{original_string}"),
          text: original_string
        }
      end
    end

    def merge(contents, string_translations, languages)
      languages.each_with_object({}) do |language, results|
        parsed_file = Nokogiri::XML(contents)
        strings_no = 0
        strings_found_no = 0

        parsed_file.xpath('//tu').each do |node|
          group = node.xpath('prop').text
          original_string = node.xpath('tuv').first.xpath('seg').text
          translated_string_node = node.xpath('tuv').last

          strings_no += 1
          token = Digest::MD5.hexdigest("#{group}_#{original_string}")
          if string_translations[[token, language.id]]
            strings_found_no += 1
            translated_string_node.xpath('seg').first.content = string_translations[[token, language.id]]
            translated_string_node.attributes.fetch('lang').content = language.iso
          else
            Rails.logger.info "String not found for #{language.name}: #{token}"
          end
        end

        results[language] = [parsed_file.to_xml, [strings_no, strings_found_no]]
      end
    end
  end

end
