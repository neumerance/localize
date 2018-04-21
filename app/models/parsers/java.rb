class Parsers::Java
  extend CharConversion

  def self.merge(contents, string_translations, languages)
    ret = {}
    string_match = /.*?=.*?(\n|$)/
    string_and_token_match = /\s*(.*?)\s*=\s*.*?/
    single_line_comment_match = /;.*?\n/

    contents = contents.delete("\000").strip
    entries = contents.scan(/(#{single_line_comment_match}|#{string_match})/)

    # strips spaces and null characters from translations in hash keys
    string_translations = Hash[string_translations.map { |k, v| [[k[0].delete("\000").strip, k[1]], v] }]

    languages.each do |language|
      output_file = ''
      strings_found = 0
      strings = 0

      entries.each do |line|
        line = line.first
        line = line.delete("\000").strip
        if line =~ string_and_token_match
          strings += 1
          if string_translations[[$1, language.id]]
            strings_found += 1
            # Remember that ENCODING JAVA should return the original value
            unencoded_string = unencode_string(string_translations[[$1, language.id]].to_s, ENCODING_JAVA)
            output_file << "#{$1}=#{unencoded_string}\n"
          else
            output_file << line + "\n"
          end
        else
          output_file << line + "\n"
        end
      end
      ret[language] = [output_file, [strings, strings_found]]
    end

    ret
  end
end
