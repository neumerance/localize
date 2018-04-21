require 'get_pomo/mo_file'

class Parsers::Po
  GENERAL_SUGGESTIONS = [
    'Multiline strings have to include open and close quotes on each line.'
  ].freeze

  class << self
    def parse(decoded_src)
      resource_strings = []

      begin
        translations = GetPomo::PoFile.parse(decoded_src)
      rescue GetPomo::InvalidString => e
        # @ToDO tests are required
        raise Parsers::ParseError.new e.message, GENERAL_SUGGESTIONS
      rescue => e
        raise Parsers::ParseError, e.message
      end

      translations.each do |translation|
        next if translation.header?

        comments = translation.comment.to_s
        if translation.msgctxt
          comments = "Context: #{translation.msgctxt}\nComment: #{comments}"
        end

        token = token_for_translation(translation)

        if translation.plural?
          resource_strings << { token: token[0],
                                text: translation.msgid[0].to_s,
                                translation: translation.msgstr[0].to_s,
                                comments: comments }
          resource_strings << { token: token[1],
                                text: translation.msgid[1].to_s,
                                translation: translation.msgstr[1].to_s,
                                comments: comments }
        else
          resource_strings << { token: token,
                                text: translation.msgid.to_s,
                                translation: translation.msgstr.to_s,
                                comments: comments }
        end
      end

      resource_strings
    end

    def merge(content, string_translations, languages)
      # trying for bom
      begin
        translations_base = GetPomo::PoFile.parse(content)
      rescue => e
        content = content[1..-1]
        translations_base = GetPomo::PoFile.parse(content)
      end
      ret = {}

      languages.each do |language|
        translations = Marshal.load(Marshal.dump(translations_base))
        strings = 0
        strings_found = 0
        translations.each do |translation|
          unless translation.msgid.blank?
            token = token_for_translation(translation)

            if translation.plural?
              strings += 2
              [0,1].each do |i|
                msgstr_translation = string_translations[[token[i], language.id]]
                if msgstr_translation
                  strings_found += 1
                  translation_string = msgstr_translation.gsub(/\n/, '\n')
                  translation.msgstr[i] = translation_string
                end
              end
            else
              strings += 1
              msgstr_translation = string_translations[[token, language.id]]
              if msgstr_translation
                strings_found += 1
                translation_string = msgstr_translation.gsub(/\n/, '\n')
                translation.msgstr = translation_string
              end
            end
          end
        end

        # Legacy: Support strings that don't have slash from quotes stripped
        escape_quotes = Regexp.new('(?<!\\\)"')

        text_translations = GetPomo::PoFile.to_text(translations)
        text_translations = text_translations.split("\n").map do |line|
          if line =~ /^(\s*(msgid(_plural)?|msgstr(\[\d\])?)\s)?"(.*)"$/
            value = $5
            line.gsub(value, value.gsub(escape_quotes, '\"'))
          else
            line
          end
        end.join("\n")

        ret[language] = [text_translations, [strings, strings_found]]
      end
      ret
    end

    private

    def token_for_translation(translation)
      base = ''

      base << translation.msgctxt if translation.msgctxt

      if translation.plural?
        [0, 1].map { |i| Digest::MD5.hexdigest(base + translation.msgid[i].to_s) }
      else
        Digest::MD5.hexdigest(base + translation.msgid.to_s)
      end
    end
  end
end
