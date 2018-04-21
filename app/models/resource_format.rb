require 'rexml/document'
require 'get_pomo'

#   kind:
#     RESOURCE_FORMAT_TEXT      = 0
#     RESOURCE_FORMAT_XML1      = 1
#     RESOURCE_FORMAT_XML2      = 2
#     RESOURCE_FORMAT_YAML      = 3
#     RESOURCE_FORMAT_ANDROID   = 4
#     RESOURCE_FORMAT_XML3      = 5

class ResourceFormat < ApplicationRecord
  include CharConversion

  KIND_NAMES = {
    RESOURCE_FORMAT_TEXT => 'Text file',
    RESOURCE_FORMAT_XML1 => 'XML file, keys in items',
    RESOURCE_FORMAT_XML2 => 'XML file, keys in attributes',
    RESOURCE_FORMAT_YAML => 'YAML file',
    RESOURCE_FORMAT_ANDROID => 'Android XML',
    RESOURCE_FORMAT_XML3 => 'XML file, no keys, text in attribute'
  }.freeze

  ENCODING_NAMES = {
    ENCODING_JAVA => 'Java Unicode (\uNNNN)',
    ENCODING_UTF8 => 'UTF-8 Unicode',
    ENCODING_UTF16_LE => 'UTF-16LE Unicode (LLHH)',
    ENCODING_UTF16_BE => 'UTF-16BE Unicode (HHLL)'
  }.freeze

  LINE_BREAK_NAMES = {
    LINE_BREAK_WINDOWS => 'Windows (\\n)',
    LINE_BREAK_UNIX => 'Unix (\\r\\n)'
  }.freeze

  LINE_BREAK_VAL = {
    LINE_BREAK_WINDOWS => "\n",
    LINE_BREAK_UNIX => "\r\n"
  }.freeze

  COMMENT_KIND_NAME = {
    0 => 'No comments',
    COMMENT_KIND_IPHONE => 'C style comment above the text line',
    COMMENT_KIND_SQUARE_BRACKETS => 'Delphi square brackets'
  }.freeze

  NIL_STR = '<span class="comment">nil</span>'.html_safe

  has_many :text_resources
  has_one :resource_upload_format

  validates_presence_of :name, :description, :encoding, :separator_char, :line_break
  validates :description, length: { maximum: COMMON_FIELD }

  def example
    label = 'some_label'
    txt = 'Text for this label'
    if kind == RESOURCE_FORMAT_XML1
      return "XML file with elements under '#{label_delimiter}'\n<#{text_delimiter}>KEY</#{text_delimiter}>\n<#{separator_char}>VALUE</#{separator_char}>"
    elsif kind == RESOURCE_FORMAT_XML2
      return "XML file with elements under '#{label_delimiter}'\n<#{separator_char} #{text_delimiter}=\"KEY\">VALUE</#{separator_char}>"
    elsif kind == RESOURCE_FORMAT_XML3
      return "XML file with '#{label_delimiter}' elements and text to translate on '#{separator_char}' attribute\n <#{label_delimiter} #{separator_char}=\"Text to translate\">"
    elsif kind == RESOURCE_FORMAT_ANDROID
      return "Android XML resource file\n<string name=\"KEY\">VALUE</string>"
    elsif kind == RESOURCE_FORMAT_YAML
      return 'Nested YAML structures'
    elsif name == 'PO alternative'
      return "msgid \"#{label}\"\nmsgstr \"#{txt}\""
    elsif name == 'PO'
      return "#: #{label}\nmsgid \"#{txt}\"\nmsgstr \"Translation...\""
    else
      return "#{label_delimiter}#{label}#{label_delimiter}#{separator_char}#{text_delimiter}#{txt}#{text_delimiter}#{end_of_line}"
    end
  end

  def extract_texts(decoded_src)

    if name == 'plist'
      old_extract_texts_from_xml1(decoded_src, self)
    elsif kind == RESOURCE_FORMAT_XML1 # 1 plist
      extract_texts_from_xml1(decoded_src, self)
    elsif kind == RESOURCE_FORMAT_XML2 # 2 IPP
      extract_texts_from_xml2(decoded_src, self)
    elsif kind == RESOURCE_FORMAT_XML3 # 5 Nevron text in attributes
      extract_texts_from_xml3(decoded_src, self)
    elsif kind == RESOURCE_FORMAT_ANDROID # 4 Android XML
      extract_texts_from_android(decoded_src)
    elsif name == 'Django'
      extract_texts_from_django(decoded_src)
    elsif name == 'PO alternative'
      alternative_parse(decoded_src)
    elsif name == 'PO'
      Parsers::Po.parse(decoded_src)
    elsif name == 'PHP Defines (double quote)'
      Parsers::Php.parse(decoded_src)
      extract_texts_from_php_double_quote(decoded_src)
    elsif ['iPhone', 'iPhone UTF-8'].include?(name)
      Parsers::Iphone.parse(decoded_src)
    elsif name == 'Xliff'
      Parsers::Xliff.parse decoded_src
    elsif name == 'Apple Stringsdict'
      Parsers::AppleStringsdict.parse decoded_src
    elsif self.name == 'Nevron Dictionary'
      Parsers::NevronDictionary.parse decoded_src
    else
      # User by:
      #   Label value pair with quotes
      #   Java unicode
      lines = decoded_src.split("\n")
      extract_texts_from_resource(lines, self)
    end
  end

  def alternative_parse(decoded_src)
    lines = decoded_src.split("\n")
    resource_strings = []
    po_strings = scan_po(lines)
    po_strings.each do |token, data|
      resource_strings << { token: Digest::MD5.hexdigest(token), text: data[0], translation: data[0], comments: data[1] }
    end
    resource_strings
  end

  def merge(contents, string_translations, languages)
    # plist
    if kind == RESOURCE_FORMAT_XML1 # 1
      translated_resources = merge_translations_to_xml1(contents, self, string_translations, languages)
    elsif kind == RESOURCE_FORMAT_XML2 # 2
      translated_resources = merge_translations_to_xml2(contents, self, string_translations, languages)
    elsif kind == RESOURCE_FORMAT_ANDROID # 4
      translated_resources = merge_translations_to_android(contents, string_translations, languages)
    elsif kind == RESOURCE_FORMAT_XML3 # 5 Nevron text in attributes
      translated_resources = merge_translations_to_xml3(contents, self, string_translations, languages)
    elsif name == 'PO alternative'
      lines = contents.split("\n")
      translated_resources = generate_pos(lines, string_translations, languages)
    elsif name == 'PO'
      translated_resources = Parsers::Po.merge(contents, string_translations, languages)
    elsif name == 'Django'
      lines = contents.split("\n")
      translated_resources = generate_django_pos(lines, string_translations, languages)
    elsif name == 'PHP Defines (double quote)'
      lines = contents.split("\n")
      translated_resources = Parsers::Php.merge(lines, string_translations, languages)
    elsif name == 'WithQuotes' # Label value pair with quotes around text
      translated_resources = merge_double_quotes(contents, string_translations, languages)
    elsif %(Delphi NoQuotes Java).include? name
      translated_resources = Parsers::Java.merge(contents, string_translations, languages)
    elsif name == 'Single quoted PHP dictionary' # Actually for double quoted too
      translated_resources = merge_php_dic(contents, string_translations, languages)
    elsif name == 'Xliff'
      Parsers::Xliff.merge(contents, string_translations, languages)
    elsif name == 'Apple Stringsdict'
      Parsers::AppleStringsdict.merge(contents, string_translations, languages)
    elsif self.name == 'Nevron Dictionary'
      Parsers::NevronDictionary.merge(contents, string_translations, languages)
    else # Apple iPhone Unicode UTF-16LE
      translated_resources = Parsers::Iphone.merge(contents, string_translations, languages)
    end
  end

  def merge_php_dic(contents, string_translations, languages)
    ret = {}

    q = /(?:'|")/
    string_match = /#{q}.*#{q}\s*=>\s*#{q}.*#{q},?/
    string_and_token_match = /\s*#{q}(.*)#{q}\s*=>\s*#{q}(.*)#{q},?/

    entries = contents.split(/\r\n|\n|\r/)

    # strips spaces from translations in hash keys
    string_translations = Hash[string_translations.map { |k, v| [[k[0].strip, k[1]], v] }]

    languages.each do |language|
      output_file = ''
      strings_found = 0
      strings = 0

      entries.each do |line|
        if line =~ string_and_token_match
          strings += 1
          if string_translations[[$1.strip, language.id]]
            strings_found += 1
            token_index = line.index('=>')
            token_with_no_arrow = line[0..token_index - 1]
            text = line[token_index..-1]
            output_file << "#{token_with_no_arrow}#{text.gsub($2, string_translations[[$1.strip, language.id]])}\n"
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

  def merge_double_quotes(contents, string_translations, languages)
    ret = {}
    string_match_single_quote = /[^\s]+\s*=\s*[^'"\r\n]*?'.*?'[^\r\n]*/m
    string_match_double_quote = /[^\s]+\s*=\s*[^'"\r\n]*?".*?"[^\r\n]*/m
    string_match = /#{string_match_single_quote}|#{string_match_double_quote}/
    others_match = /^.*?\n/
    entries_match = /(?:#{string_match})|(?:#{others_match})/

    entries = contents.scan(/#{entries_match}/)

    # strips spaces from translations in hash keys
    string_translations = Hash[string_translations.map { |k, v| [[k[0].strip, k[1]], v] }]

    # iclsupp-926 This regex was not allowing quotes on the label, but a client had with quotes.
    #  I can't see a reason to avoid quotes on the label so it's removed. Original: /^\s*([^"\s]+?)\s*=
    string_and_token_match_single_quote = /^\s*(.+?)\s*=\s*[^'\r\n]*?'(.*?)'[^\r\n]*/m
    string_and_token_match_double_quote = /^\s*(.+?)\s*=\s*[^"\r\n]*?"(.*?)"[^\r\n]*/m

    languages.each do |language|
      output_file = ''
      strings_found = 0
      strings = 0

      entries.each do |line|
        if line =~ string_and_token_match_single_quote || line =~ string_and_token_match_double_quote
          strings += 1
          if string_translations[[$1.strip, language.id]]
            strings_found += 1
            translation = string_translations[[$1.strip, language.id]]

            quote = line =~ string_and_token_match_single_quote ? "'" : '"'
            line = line.sub /^(\s*.+?\s*=\s*[^#{quote}\r\n]*?#{quote}).*?(#{quote}[^\r\n]*)/m, "\\1#{translation}\\2"
          end
        end
        output_file << line
      end
      ret[language] = [output_file, [strings, strings_found]]
    end

    ret
  end

  def extract_texts_from_django(decoded_src)
    lines = decoded_src.split("\n")
    resource_strings = []
    po_strings = scan_po(lines, true)
    po_strings.each do |token, data|
      resource_strings << { token: Digest::MD5.hexdigest(token), text: token, translation: data[0], comments: data[1] }
    end
    resource_strings
  end

end
