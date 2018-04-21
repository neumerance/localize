class Parsers::AppleStringsdict

  class << self

    IGNORED_KEYS = %w(NSStringFormatSpecTypeKey NSStringFormatValueTypeKey).freeze

    def parse(decoded_src)
      plist_xml = Nokogiri::XML(decoded_src)

      results = plist_xml.xpath('//dict/dict/dict').each_with_object([]) do |dict, resource_strings|
        keys = dict.xpath('key')
        strings = dict.xpath('string')

        new_strings = (keys.zip strings).each_with_object([]) do |(key, string), r|
          next if IGNORED_KEYS.include? key.text
          r << {
            comments: key.text,
            token: "#{key.text}: #{string.text}",
            text: string.text
          }
        end
        resource_strings << new_strings
      end
      results.flatten
    end

    def merge(contents, string_translations, languages)

      languages.each_with_object({}) do |language, results|
        plist_file = Nokogiri::XML(contents)
        strings_no = 0
        strings_found_no = 0

        plist_file.xpath('//dict/dict/dict').each do |dict|
          keys = dict.xpath('key')
          strings = dict.xpath('string')

          (keys.zip strings).each do |key, string|
            next if IGNORED_KEYS.include? key.text
            strings_no += 1
            token = "#{key.text}: #{string.text}"
            if string_translations[[token, language.id]]
              strings_found_no += 1
              string.content = string_translations[[token, language.id]]
            else
              Rails.logger.info "String not found for #{language.name}: #{token}"
            end
          end
        end

        results[language] = [plist_file.to_xml, [strings_no, strings_found_no]]
      end
    end
  end

end
