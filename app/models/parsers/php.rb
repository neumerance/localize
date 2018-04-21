class Parsers::Php
  def self.merge(lines, string_translations, languages)
    # Format: [language] = [translation, stats] - todo: split this
    file_header = "<?php\n"
    file_footer = '?>'

    ret = {}
    text = /(\".*?\")/
    token = /[a-zA-Z0-9"'_-]*/
    languages.each do |language|
      output_file = Marshal.load(Marshal.dump(file_header))
      strings_found = 0
      strings = 0
      lines.each do |line|
        if line =~ /.*?define\((#{token}).*?,.*?(#{text})\);/
          strings += 1
          if string_translations[[$1, language.id]]
            strings_found += 1
            output_file << line.gsub($2, string_translations[[$1, language.id]]) + "\n"
          else
            output_file << line + "\n"
          end
        else
          output_file << line + "\n"
        end
      end
      output_file << file_footer
      ret[language] = [output_file, [strings, strings_found]]
    end
    ret
  end

  def self.parse(decoded_src)
    lines = decoded_src.split("\n")
    resource_strings = []
    # define("REGISTER_TODAY", "Register Today!");
    lines.each do |line|
      text = /\".*?\"/
      token = /[a-zA-Z0-9"'_-]*/
      if line =~ /.*?define\(\s*(#{token}).*?,.*?(#{text})\s*\);/
        # logger.debug $1.inspect
        resource_strings << { token: $1, text: $2, translation: $2, comments: '' }
      end
    end
    resource_strings
  end
end
