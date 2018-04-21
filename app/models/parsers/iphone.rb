class Parsers::Iphone

  MATCH_SINGLELINE_COMMENT = /\/\/(.*)$/
  MATCH_MULTILINE_COMMENT = /\/\*(.*?)\*\//m
  MATCH_STRING = /\s*?"(.*?)"\s*?=\s*?"((\\"|[^"])*?)"\s*?\;?\s*/xm

  def self.parse(decoded_src)
    out = decoded_src.scan(/(?:#{MATCH_SINGLELINE_COMMENT}*?|#{MATCH_MULTILINE_COMMENT}*?)\s*?#{MATCH_STRING}/)
    resource_strings = []
    out.each do |capture|
      resource_strings << {
        comments: (capture[0] || capture[1]).try(:strip),
        token: capture[2],
        text: capture[3],
        translation: capture[3]
      }
    end
    resource_strings
  end

  def self.merge(contents, string_translations, languages)
    ret = {}

    entries = contents.scan(/(#{MATCH_SINGLELINE_COMMENT}|#{MATCH_MULTILINE_COMMENT}|#{MATCH_STRING})/)

    escape_quotes = Regexp.new('(?<!\\\)"')
    string_match_for_replace_translation = /(\s*?"(?:.*?)"\s*?=\s*?"\s*)((?:\\"|[^"])*?)(\s*"\s*?\;?\s*)/xm

    languages.each do |language|
      output_file = ''
      strings_found = 0
      strings = 0

      entries.each do |line|
        line = line.first
        if line =~ MATCH_STRING
          strings += 1
          token = truncate_name($1)
          untranslated_string = $2
          if string_translations[[token, language.id]]
            strings_found += 1
            translation = string_translations[[token, language.id]].gsub(escape_quotes, '\"')
            line[string_match_for_replace_translation]
            output_file << $1 + translation + $3
          else
            Rails.logger.debug "String not found for #{language.name}: #{token}"
            output_file << line
          end
        else
          output_file << line
        end
      end
      ret[language] = [output_file, [strings, strings_found]]
    end

    ret
  end

  private_class_method

  def self.truncate_name(name)
    if name.length <= MAX_STR_LENGTH
      name
    else
      name[0..MAX_STR_LENGTH - 1]
    end
  end
end
