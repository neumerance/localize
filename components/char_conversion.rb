# encoding: utf-8
require 'yaml'
require 'nokogiri'

#   0: Java Unicode
#   1: UTF-8
#   2: Unicode (UTF-16LE)
#   3: Unicode (UTF-16BE)
module CharConversion
  RESOURCE_NAME = {
    ENCODING_JAVA     => 'Java Unicode',
    ENCODING_UTF8     => 'UTF-8',
    ENCODING_UTF16_LE => 'Unicode (UTF-16LE)',
    ENCODING_UTF16_BE => 'Unicode (UTF-16BE)'
  }.freeze

  # utf16: If there is no BOM, one method of recognizing a UTF-16 encoding is
  #        searching for the space character (U+0020)
  BOMS = {
    'UTF-8' => "\xEF\xBB\xBF".force_encoding('UTF-8'),
    'UTF-32BE' => "\x00\00\xFE\xFF".force_encoding('UTF-32BE'),
    'UTF-32LE' => "\xFF\xFE\x00\x00".force_encoding('UTF-32LE'),
    'UTF-16BE' => "\xFE\xFF".force_encoding('UTF-16BE'),
    'UTF-16LE' => "\xFF\xFE".force_encoding('UTF-16LE')
  }.freeze

  UTF16_NAMES = {
    ENCODING_UTF16_LE => 'UTF-16LE',
    ENCODING_UTF16_BE => 'UTF-16BE'
  }.freeze

  UTF16_BOM = {
    'UTF-16LE' => BOMS['UTF-16LE'],
    'UTF-16BE' => BOMS['UTF-16BE']
  }.freeze

  JAVA_RE = /\\u[a-fA-F0-9]{4}/u

  ICL_TOKEN = '$ICL_TOKEN_REPLACE$'.freeze

  ICL_CREDIT_TOKEN = 'ICL_translation_credit'.freeze
  ICL_AFFILIATE_URL_TOKEN = 'ICL_affiliate_URL'.freeze

  def remove_bom(txt) # and converto to UTF-8
    bin_buffer = txt.dup.force_encoding(Encoding::BINARY)

    BOMS.each do |encoding, bom|
      next unless bin_buffer[0, bom.bytes.count].bytes == bom.bytes
      txt.force_encoding(encoding)
      txt = txt[1..-1] if txt[0] == BOMS[encoding]
      break
    end

    convert_to_utf8(txt, threat_as_utf8_on_error: true)
  end

  # Convert utf16 be/le, utf32 be/le and utf8-java encoding to UTF-8
  # encoding_index is the index (check comment at the beggining of this file)
  #  that txt is suppose to be encoded. However we are not trusting 100% on this
  #  value. We try to identify the correct encoding.
  #
  def unencode_string(txt, encoding_index, leave_bom = false)
    # try to guess encoding:
    detection = CharDet.detect txt
    source_encoding = if detection['confidence'] == 1.0
                        detection['encoding']
                      elsif UTF16_NAMES.keys.include? encoding_index
                        UTF16_NAMES[encoding_index]
                      else
                        false
                      end

    txt = convert_to_utf8(txt, source_encoding: source_encoding)

    if encoding_index == ENCODING_JAVA
      txt = txt.gsub(JAVA_RE) do |s|
        java_to_utf8(s).force_encoding('UTF-8')
      end
      txt.force_encoding('UTF-8')
    end

    txt = remove_bom(txt) unless leave_bom

    txt
  rescue => e
    Parsers.logger("Failed to encode unencode_string. encoding: #{encoding_index}, error: ", e, true)
    nil
  end

  def convert_to_utf8(txt, source_encoding: nil, threat_as_utf8_on_error: false)
    source_encoding ||= txt.encoding

    unless source_encoding.to_s == 'UTF-8'
      begin
        txt = Encoding::Converter.new(source_encoding, 'UTF-8').convert(txt)
      rescue => e
        # Not able to convert to UTF-8 probably is US-ASCII
        Parsers.logger("Not able to convert to UTF-8 encoding: #{txt.encoding}, error: #{e.message}", e)
        txt.force_encoding('UTF-8') if threat_as_utf8_on_error
      end
    end

    txt
  end

  def encode_string(txt, encoding_index, bom = false)
    if encoding_index == ENCODING_UTF8
      return BOMS['UTF-8'] + txt if bom && !txt.start_with?(BOMS['UTF-8'])
      return txt
    end
    return encode_java_string(txt) if encoding_index == ENCODING_JAVA

    # txt.encode(UTF16_NAMES[encoding])
    conv = Encoding::Converter.new('UTF-8', UTF16_NAMES[encoding_index])
    txt = conv.convert(txt)

    if bom && !txt.start_with?(UTF16_BOM[UTF16_NAMES[encoding_index]])
      UTF16_BOM[UTF16_NAMES[encoding_index]] + txt
    else
      txt
    end
  end

  def encode_java_string(txt)
    txt.chars.map do |symbol|
      if symbol.ascii_only?
        symbol
      else
        '\\u%04x' % symbol.ord
      end
    end.join
  end

  def java_to_utf8(str)
    # first, calculate the decimal value
    dec = 0
    for idx in 2...str.length
      dec *= 16
      ch = str[idx].ord
      dec += if (ch >= 'a'.ord) && (ch <= 'f'.ord)
               ch - 'a'.ord + 10
             elsif (ch >= 'A'.ord) && (ch <= 'F'.ord)
               ch - 'A'.ord + 10
             else # (ch >= '0'.ord) && (ch <= '9'.ord) this condition is not executed. Use elsif instead
               ch - '0'.ord
             end
    end

    utf8(dec)
  end

  def utf8(dec)
    res = if dec < 0x80
            dec.chr
          elsif dec < 0x800
            (0xc0 | (dec >> 6)).chr + (0x80 | (dec & 0x3f)).chr
          elsif dec < 0x10000
            (0xe0 | (dec >> 12)).chr + (0x80 | (dec >> 6) & 0x3f).chr + (0x80 | (dec & 0x3f)).chr
          else
            (0xf0 | (dec >> 18)).chr + (0x80 | (dec >> 12) & 0x3f).chr + (0x80 | (dec >> 6) & 0x3f).chr + (0x80 | (dec & 0x3f)).chr
          end
    res
  end

  def utf8_length(txt)
    cnt = 0
    len = 0
    for idx in 0..txt.length
      o = txt[idx]
      if cnt == 0
        # not inside multi-byte sequence
        if (o & 0x80) == 0
          len += 1
        elsif (o & 0xe0) == 0xc0
          cnt = 1
        elsif (o & 0xf0) == 0xe0
          cnt = 2
        elsif (o & 0xf8) == 0xf0
          cnt = 3
        end
      else
        cnt -= 1
        len += 1 if cnt == 0
      end
    end
    len += 1 if cnt != 0
    len
  end

  # this counts the number of zero characters in a string. We use it to check if a string is encoded as UTF16
  def is_utf_16?(str)
    return false if str.blank?

    cnt = 0
    (0..str.length).each do |idx|
      cnt += 1 if str[idx] == 0
    end
    (cnt > (str.length / 4).to_i)
  end

  def include_emoji?(txt)
    Rumoji.encode(txt) != txt
  end
  module_function :include_emoji?

  #############################################################################
  # @ToDO The code below is related to parsers, not to char conversion
  #       it should be moved out of this file

  def add_translations(res_lines, total, completed, name, txt, languages, string_translations, separator, label_delimiter, text_delimiter, end_of_line)
    languages.each do |language|
      translation = string_translations[[truncate_name(name), language.id]]
      if !translation && (name == ICL_CREDIT_TOKEN)
        if ICL_CREDIT_FOOTER.key?(language.name)
          translation = ICL_CREDIT_FOOTER[language.name]
        end
        completed[language] += 1
      end
      completed[language] += 1 if txt.empty?
      if translation
        unless text_delimiter.blank?
          s = '\\'
          esc_del = '$ICL_ALREADY_DELIMITED'
          translation = translation.gsub(s + text_delimiter, esc_del).gsub(text_delimiter, s + text_delimiter).gsub(esc_del, s + text_delimiter)
        end
        completed[language] += 1
      else
        translation = txt
      end
      total[language] += 1
      res_lines[language] << "#{label_delimiter}#{name}#{label_delimiter} #{separator} #{text_delimiter}#{translation}#{text_delimiter}#{end_of_line}"
    end
  end

  def strip_delimiter(txt, delimiter)
    return txt unless delimiter

    del_start = txt.index(delimiter)
    del_end = txt.rindex(delimiter)
    if del_start && del_end && (del_start >= 0) && (del_end >= 0)
      return txt[(del_start + 1)...del_end]
    else
      return txt
    end
  end

  # the po_file can be either an open file to read from or already an array of lines
  def scan_po(po_file, preserve_line_breaks = false)

    res = {}

    comments = []
    flags = nil
    msgid = nil
    msgstr = nil
    plural_id = nil
    plural_str = nil
    mode = nil # 0 - not accumulating, 1 - in msgid, 2 - in msgstr

    lines = if po_file.class == Array
              po_file
            else
              po_file.readlines
            end

    lines.each do |line_w_cr|
      line = line_w_cr.delete("\n").delete("\r")

      if ['# ', '#.', '#:'].include? line[0...2]
        mode = nil
        comment = line[2..-1].gsub('\"', '"').gsub('\\\\', '\\')
        comments << comment
      elsif line[0...2] == '#,'
        mode = nil
        flags = line[3..-1]
      elsif line[0...12] == 'msgid_plural'
        mode = 'plural_id'
        plural_id = strip_quotes(line[13..-1]).gsub('\"', '"').gsub('\\\\', '\\')
      elsif line[0...5] == 'msgid'
        mode = 'msgid'
        msgid = strip_quotes(line[6..-1]).gsub('\"', '"').gsub('\\\\', '\\')
      elsif (line[0...9] =~ /msgstr\[(\d)\]/) == 0
        mode = 'plural_str'

        if $1 == '0'
          msgstr = strip_quotes(line[10..-1]).gsub('\"', '"').gsub('\\\\', '\\')
        else
          if $1 == '1'
            plural_str = "#{strip_quotes(line[10..-1]).gsub('\"', '"').gsub('\\\\', '\\')}"
          else
            plural_str += "\n#{PLURAL_SEPARATOR}\n#{strip_quotes(line[10..-1]).gsub('\"', '"').gsub('\\\\', '\\')}"
          end

          plural_id = plural_str
        end
      elsif line[0...6] == 'msgstr'
        mode = 'msgstr'
        msgstr = strip_quotes(line[7..-1]).gsub('\"', '"').gsub('\\\\', '\\')
      elsif line[0..0] == '"'
        val = strip_quotes(line).gsub('\"', '"').gsub('\\\\', '\\')

        if mode == 'msgid'
          msgid += "\n" if preserve_line_breaks
          msgid += val
        elsif mode == 'msgstr'
          msgstr += "\n" if preserve_line_breaks
          msgstr += val
        elsif mode == 'plural_id'
          plural_id += "\n" if preserve_line_breaks
          plural_id += val
        elsif mode == 'plural_str'
          plural_str ||= ''
          plural_str += "\n" if preserve_line_breaks
          plural_str += val
        end
      elsif line == ''
        unless msgid.blank?
          if !plural_id.blank?
            comments << "This string has singular and plural forms. The translation must preserve the #{PLURAL_SEPARATOR} between them."
            res[encode_plural(msgid, plural_id)] = [encode_plural(msgstr, plural_str), comments.join("\n")]
          else
            res[msgid] = [msgstr, comments.join("\n")]
          end
        end

        mode = nil
        comments = []
        flags = nil
        msgid = nil
        msgstr = nil
        plural_id = nil
        plural_str = nil
      end
    end

    # close the last item
    unless msgid.blank?
      if !plural_id.blank?
        comments << "This string has singular and plural forms. The translation must preserve the #{PLURAL_SEPARATOR} between them."
        res[encode_plural(msgid, plural_id)] = [encode_plural(msgstr, plural_str), comments.join("\n")]
      else
        res[msgid] = [msgstr, comments.join("\n")]
      end
    end

    res
  end

  def encode_plural(single, plural)
    "#{single || ''}\n#{PLURAL_SEPARATOR}\n#{plural || ''}"
  end

  def strip_quotes(txt)
    txt[1...-1]
  end

  def generate_pos(lines, existing_translation, languages)

    po_header = ''
    po_header += "msgid \"\"\n"
    po_header += "msgstr \"\"\n"
    po_header += "\"Content-Type: text/plain; charset=utf-8\\n\"\n"
    po_header += '"Content-Transfer-Encoding: 8bit\\n"'

    po_dict = scan_po(lines)

    keys = po_dict.keys().sort

    res = {}
    languages.each do |language|

      total = 0
      completed = 0

      lines = [po_header]

      keys.each do |txt|

        token = Digest::MD5.hexdigest(txt)
        dict_key = [token, language.id]
        if existing_translation.key?(dict_key) && !existing_translation[dict_key].blank?
          msgstr = existing_translation[dict_key]
          completed += 1

          # output only if there's translation
          lines << ''

          # escape for the PO file
          msgid = escape_quotes(txt)
          msgstr = escape_quotes(msgstr.delete("\r"))

          # Append \n at the start or at the end if there is a plural and has
          # no new characters at the start or end.
          if msgid =~ /#{Regexp.escape(PLURAL_SEPARATOR)}/
            msgstr = " \n#{msgstr}" if msgstr =~ /\A#{Regexp.escape(PLURAL_SEPARATOR)}/
            msgstr = "#{msgstr}\n " if msgstr =~ /#{Regexp.escape(PLURAL_SEPARATOR)}\Z/
          end

          msgids = msgid.split /\n\s*#{Regexp.escape(PLURAL_SEPARATOR)}\s*\n/
          msgstrs = msgstr.split /\n\s*#{Regexp.escape(PLURAL_SEPARATOR)}\s*\n/

          if (msgids.length > 1) && (msgstrs.length > 1)
            lines << "msgid \"#{msgids[0]}\""
            lines << "msgid_plural \"#{msgids[1]}\""

            msgstrs.each_with_index do |msg, index|
              msg.gsub!(/\n/, '\n')
              lines << "msgstr[#{index}] \"#{msg}\""
            end
          else
            msgstr.gsub!(/\n/, '\n')
            lines << "msgid \"#{msgid}\""
            lines << "msgstr \"#{msgstr}\""
          end

          # else
          # logger.info "------ cannot find translation for \"%s\" => \"%s\""%[token, txt]
        end
        total += 1

      end

      res[language] = [lines.join("\n"), [total, completed]]
    end
    res
  end

  def generate_django_pos(lines, existing_translation, languages)

    po_header = ''
    po_header += "msgid \"\"\n"
    po_header += "msgstr \"\"\n"
    po_header += "\"Content-Type: text/plain; charset=utf-8\\n\"\n"
    po_header += '"Content-Transfer-Encoding: 8bit\\n"'

    po_dict = scan_po(lines, true)

    keys = po_dict.keys().sort

    res = {}
    languages.each do |language|

      total = 0
      completed = 0

      lines = [po_header]

      keys.each do |token|

        msgstr = po_dict[token][0]
        dict_key = [Digest::MD5.hexdigest(token), language.id]
        if existing_translation.key?(dict_key) && !existing_translation[dict_key].blank?
          msgstr = existing_translation[dict_key]
          completed += 1
        end

        # output only if there's translation
        lines << ''

        # escape for the PO file
        msgid = escape_quotes(token)
        msgstr = escape_quotes(msgstr.delete("\r"))

        lines << "msgid \"#{msgid}\""

        first = true
        msgstr.split("\n").each do |msgstr_part|
          lines << if first
                     "msgstr \"#{msgstr_part}\""
                   else
                     "\"#{msgstr_part}\""
                   end
          first = false
        end

        total += 1

      end

      res[language] = [lines.join("\n"), [total, completed]]
    end
    res
  end

  def generate_standalone_pos(existing_translation, languages)

    po_header = ''
    po_header += "msgid \"\"\n"
    po_header += "msgstr \"\"\n"
    po_header += "\"Content-Type: text/plain; charset=utf-8\\n\"\n"
    po_header += '"Content-Transfer-Encoding: 8bit\\n"'

    keys = existing_translation.keys().sort

    res = {}
    languages.each do |language|

      lines = [po_header]

      total = 0
      completed = 0

      keys.each do |txt|

        if existing_translation.key?(txt) && existing_translation[txt].key?(language.id) && !existing_translation[txt][language.id].blank?
          msgstr = existing_translation[txt][language.id]
          completed += 1

          lines << ''

          # escape for the PO file
          msgid = escape_quotes(txt)
          msgstr = escape_quotes(msgstr)

          lines << "msgid \"#{msgid}\""
          lines << "msgstr \"#{msgstr}\""

        end
        total += 1
      end

      res[language] = [lines.join("\n"), [total, completed]]
    end
    res
  end

  def escape_quotes(txt)
    txt.gsub('\\"', '$ICL_SLASH_N_BREAK').gsub(' \\ ', ' \\\\\\ ').gsub('"', '\"').gsub('$ICL_SLASH_N_BREAK', '\\"')
  end

  def fix_basic_entity(content)
    content.gsub(/&(?!(?:amp|lt|gt|quot|apos|#\d+);)/, '&amp;')
  end

  # --- XML functions ---
  # handles XML files with keys and data in seperate tags
  # Used by plist parser
  def old_extract_texts_from_xml1(txt, resource_format)
    res = []

    begin
      doc = REXML::Document.new(fix_basic_entity(txt))
    rescue REXML::ParseException => e
      err = 'Error parsing the XML file.'
      if e.source
        err << "\nLine: #{e.line}\n"
        err << "Position: #{e.position}\n"
        if e.continued_exception
          err << "Offending section: #{e.continued_exception.message}\n"
        end
        err << "Last 80 unconsumed characters:\n"
        err << e.source.buffer[0..80].force_encoding('ASCII-8BIT').tr("\n", ' ')
      end

      Parsers.logger(err, e)
      raise Parsers::ParseError, err
    end

    path = resource_format.label_delimiter
    key_tag = resource_format.text_delimiter
    value_tag = resource_format.separator_char
    array_tag = resource_format.multiline_char
    dict_tag = resource_format.end_of_line

    doc.elements.each(path) do |entry|

      key = nil
      entry.elements.each do |element|
        begin
          text = element.text
        rescue
          text = nil
        end

        if (element.name == key_tag) && !text.blank?
          key = text
        elsif key && !array_tag.blank? && (element.name == array_tag)
          element.elements.each(value_tag) do |array_item|
            # begin
            item_text = array_item.text
            # rescue
            # item_text = nil
            # logger.info "----------- problem with text"
            # end
            next if item_text.blank?
            item_index = Digest::MD5.hexdigest(item_text)
            array_key = "#{key}_#{item_index}"
            res << { token: array_key, text: item_text, translation: item_text, comments: '' }
          end
          key = nil
        elsif key && !dict_tag.blank? && (element.name == dict_tag)
          recursive_element_scan(element, key_tag, value_tag, array_tag, dict_tag, key, res)
          key = nil
        elsif key && (element.name == value_tag) && !text.blank?
          res << { token: key, text: text, translation: text, comments: '' }
          key = nil
        end

      end
    end

    res
  end

  def extract_texts_from_xml1(txt, resource_format)
    res = []

    begin
      doc = REXML::Document.new(txt)
    rescue REXML::ParseException => e
      Parsers.logger('Error parsing file with REXML', e)
      raise Parsers::ParseError, 'Not able to parse file, please contact support providing the uploaded file.'
    end

    path = resource_format.label_delimiter
    key_tag = resource_format.text_delimiter
    value_tag = resource_format.separator_char
    array_tag = resource_format.multiline_char
    dict_tag = resource_format.end_of_line

    doc.elements.each(path) do |entry|
      recursive_element_scan(entry, key_tag, value_tag, array_tag, dict_tag, '', res)
    end

    res
  end

  def recursive_element_scan(entry, key_tag, value_tag, array_tag, dict_tag, prev_path, res)
    key = nil
    entry.elements.each do |element|
      begin
        text = element.text
      rescue
        text = nil
      end

      if (element.name == key_tag) && !text.blank?
        key = text
      elsif key && !array_tag.blank? && (element.name == array_tag)
        element.elements.each(value_tag) do |array_item|
          begin
            item_text = array_item.text
          rescue
            item_text = nil
          end
          next if item_text.blank?
          item_index = Digest::MD5.hexdigest(item_text)
          array_key = "#{key}_#{item_index}"
          res << { token: "#{prev_path}/#{array_key}", text: item_text, translation: item_text, comments: '' }
        end
        key = nil
      elsif key && !dict_tag.blank? && (element.name == dict_tag)
        recursive_element_scan(element, key_tag, value_tag, array_tag, dict_tag, "#{prev_path}/#{key}", res)
        key = nil
      elsif key && (element.name == value_tag) && !text.blank?
        res << { token: "#{prev_path}/#{key}", text: text, translation: text, comments: '' }
        key = nil
      end

    end

  end

  # handles XML files with keys and data in the same tag
  def extract_texts_from_xml2(txt, resource_format)
    res = []

    begin
      doc = REXML::Document.new(txt)
    rescue REXML::ParseException => e
      Parsers.logger('Error parsing file with REXML', e)
      raise Parsers::ParseError, 'Not able to parse file, please contact support providing the uploaded file.'
    end

    path = resource_format.label_delimiter
    key_attribute = resource_format.text_delimiter
    value_tag = resource_format.separator_char

    doc.elements.each(path) do |entry|

      entry.elements.each do |element|
        begin
          text = element.text
        rescue
          text = nil
        end

        next unless (element.name == value_tag) && !text.blank?
        key = element.attributes[key_attribute]
        unless key.blank?
          res << { token: key, text: text, translation: text, comments: '' }
        end

      end
    end

    res

  end

  # nevron Dictionary
  # <item key="text to translate">
  def extract_texts_from_xml3(txt, resource_format)
    res = []

    begin
      doc = REXML::Document.new(txt)
    rescue REXML::ParseException => e
      Parsers.logger('Error parsing file with REXML', e)
      raise Parsers::ParseError, 'Not able to parse file, please contact support providing the uploaded file.'
    end

    path = resource_format.label_delimiter
    key_attribute = resource_format.text_delimiter
    value_attr = resource_format.separator_char

    doc.elements.each(path) do |element|
      text = element.attributes[value_attr]

      next if text.blank?
      key = element.attributes[key_attribute]
      if key.blank?
        item_index = Digest::MD5.hexdigest(text)
        begin
          # Try to get the value of the first attribute of parent
          #   <category name="Presentation">
          key = element.parent.attributes.first[1]
        rescue
          key = ''
        end
        key = "#{key}_#{item_index}"
      end

      res << { token: key, text: text, translation: text, comments: '' }
    end

    res

  end

  def extract_texts_from_android(txt)
    res = []
    begin
      doc = REXML::Document.new(txt)
      formatter = REXML::Formatters::Default.new
    rescue REXML::ParseException => e
      Parsers.logger('Error parsing file with REXML', e)
      raise Parsers::ParseError, 'Not able to parse file, please contact support providing the uploaded file.'
    end

    doc.elements.each do |entry|

      entry.elements.each('string') do |element|

        key = element.attributes['name']
        comment = element.attributes['comment']

        text = ''

        formatter.write_element_content(element, text)

        if !key.blank? && !text.blank?
          res << { token: key, text: text, translation: text, comments: comment }
        end

      end

      entry.elements.each('string-array') do |element|
        key = element.attributes['name']
        parent_comment = element.attributes['comment']
        next if key.blank?
        idx = 1
        element.elements.each('item') do |item|
          comment = item.attributes['comment']
          commentadd = item.attributes['commentadd']

          text = ''
          formatter.write_element_content(item, text)

          unless text.blank?
            res << { token: "#{key}-#{idx}", text: text, translation: text, comments: calc_comment(parent_comment, comment, commentadd) }
          end

          idx += 1
        end
      end

      entry.elements.each('plurals') do |element|
        key = element.attributes['name']
        parent_comment = element.attributes['comment']
        next if key.blank?
        element.elements.each('item') do |item|
          comment = item.attributes['comment']
          commentadd = item.attributes['commentadd']
          text = ''
          formatter.write_element_content(item, text)

          quantity = item.attributes['quantity']

          if !quantity.blank? && !text.blank?
            res << { token: "#{key}-#{quantity}", text: text, translation: text, comments: calc_comment(parent_comment, comment, commentadd) }
          end

        end
      end

    end

    # replace XML control characters
    # res.each do |entry|
    # entry[1] = entry[1].gsub('&apos;',"'").gsub('&quot;','"').gsub('&amp;','&')
    # end

    res

  end

  def calc_comment(parent_comment, comment, commentadd)
    the_comment = nil
    if comment
      the_comment = comment
    elsif parent_comment
      the_comment = parent_comment
    end

    if commentadd
      the_comment = '' unless the_comment
      the_comment += ("\n" + commentadd)
    end

    the_comment
  end

  def merge_translations_to_xml1(txt, resource_format, string_translations, languages)
    res = {}

    path = resource_format.label_delimiter
    key_tag = resource_format.text_delimiter
    value_tag = resource_format.separator_char
    array_tag = resource_format.multiline_char
    dict_tag = resource_format.end_of_line

    formatter = REXML::Formatters::Default.new

    total = 0
    completed = 0

    languages.each do |language|
      doc = REXML::Document.new(txt)
      doc.context[:attribute_quote] = :quote

      doc.elements.each(path) do |entry|
        total_r, completed_r = recursive_element_translate(entry, key_tag, value_tag, array_tag, dict_tag, '', string_translations, language)

        total += total_r
        completed += completed_r
      end

      t = ''
      formatter.write(doc, t)

      if !t.starts_with?("<\?xml") && !t.starts_with?("﻿<\?xml")
        t = '<?xml version="1.0" encoding="UTF-8"?>' + "\n" + t
      end

      res[language] = [t, [total, completed]]

    end

    res

  end

  def recursive_element_translate(entry, key_tag, value_tag, array_tag, dict_tag, prev_path, string_translations, language)
    key = nil
    total = 0
    completed = 0
    entry.elements.each do |element|

      begin
        text = element.text
      rescue
        text = nil
      end

      if (element.name == key_tag) && !text.blank?
        key = text
      elsif key && !array_tag.blank? && (element.name == array_tag)
        element.elements.each(value_tag) do |array_item|
          begin
            item_text = array_item.text
          rescue
            item_text = nil
          end
          next if item_text.blank?
          item_index = Digest::MD5.hexdigest(item_text)
          array_key = "#{key}_#{item_index}"

          translation = string_translations[[prev_path + truncate_name(array_key), language.id]]
          unless translation.blank?
            array_item.text = translation
            completed += 1
          end
          total += 1

        end
        key = nil
      elsif key && !dict_tag.blank? && (element.name == dict_tag)
        total_r, completed_r = recursive_element_translate(element, key_tag, value_tag, array_tag, dict_tag, prev_path + key + '/', string_translations, language)
        total += total_r
        completed += completed_r

        key = nil
      elsif key && (element.name == value_tag) && !text.blank?

        translation = string_translations[[prev_path + truncate_name(key), language.id]]
        unless translation.blank?
          element.text = translation
          completed += 1
        end
        total += 1

        key = nil
      end
    end
    [total, completed]
  end

  def merge_translations_to_xml2(txt, resource_format, string_translations, languages)
    res = {}

    path = resource_format.label_delimiter
    key_attribute = resource_format.text_delimiter
    value_tag = resource_format.separator_char

    formatter = REXML::Formatters::Default.new

    languages.each do |language|

      total = 0
      completed = 0

      doc = REXML::Document.new(txt)
      doc.context[:attribute_quote] = :quote

      doc.elements.each(path) do |entry|

        entry.elements.each do |element|

          begin
            text = element.text
          rescue
            text = nil
          end

          next unless (element.name == value_tag) && !text.blank?

          key = element.attributes[key_attribute]
          next if key.blank?
          translation = string_translations[[truncate_name(key), language.id]]
          unless translation.blank?
            element.text = translation
            completed += 1
          end
          total += 1
        end
      end

      t = ''
      formatter.write(doc, t)

      if !t.starts_with?('<?xml') && !t.starts_with?('﻿<?xml')
        t = '<?xml version="1.0" encoding="UTF-8"?>' + "\n" + t
      end

      res[language] = [t, [total, completed]]

    end

    res

  end

  def merge_translations_to_xml3(txt, resource_format, string_translations, languages)
    res = {}

    path = resource_format.label_delimiter
    key_attribute = resource_format.text_delimiter
    value_attr = resource_format.separator_char

    formatter = REXML::Formatters::Default.new

    languages.each do |language|

      total = 0
      completed = 0

      doc = REXML::Document.new(txt)
      doc.context[:attribute_quote] = :quote

      doc.elements.each(path) do |element|

        begin
          text = element.attributes[value_attr]
        rescue
          text = nil
        end

        next if text.blank?

        key = element.attributes[key_attribute]
        if key.blank?
          item_index = Digest::MD5.hexdigest(text)
          begin
            # Try to get the value of the first attribute of parent
            #   <category name="Presentation">
            key = element.parent.attributes.first[1]
          rescue
            key = ''
          end
          key = "#{key}_#{item_index}"
        end

        next if key.blank?
        translation = string_translations[[truncate_name(key), language.id]]
        unless translation.blank?
          # element.text = translation
          element.attributes['value'] = translation
          completed += 1
        end
        total += 1

      end

      t = ''
      formatter.write(doc, t)

      if !t.starts_with?('<?xml') && !t.starts_with?('﻿<?xml')
        t = '<?xml version="1.0" encoding="UTF-8"?>' + "\n" + t
      end

      res[language] = [t, [total, completed]]

    end

    res

  end

  def update_node_translation(key, node, language, string_translations, translation_replacements, completed, total)
    translation = string_translations[[truncate_name(key), language.id]]
    unless translation.blank?
      token = ICL_TOKEN + Digest::MD5.hexdigest(translation)

      if translation =~ /<!\[CDATA\[/
        # CDATA don't plays well with HTML.fragment.
        translation_replacements[token] = translation
      else
        doc = Nokogiri::HTML.fragment(translation)
        doc.traverse do |x|
          if x.is_a? Nokogiri::XML::Text
            # It is necessary to escape single quotes for android files. They are not
            # standard XMLs.
            # Referece: http://developer.android.com/guide/topics/resources/string-resource.html
            x.content = x.to_s.
                        gsub('\\"', '$ICL_ESCAPTED_QUOTE').
                        gsub("\\'", '$ICL_ESCAPTED_APOS').
                        gsub("'", "\\\\'").
                        gsub('"', '\\\\"').
                        # gsub('"','&quot;').
                        gsub('$ICL_ESCAPTED_APOS', "\\\\'").
                        # gsub(' & ',' &amp; ').
                        gsub('$ICL_ESCAPTED_QUOTE', '\\"')
          end
        end

        translation_replacements[token] = doc.to_s.gsub(/&amp;([a-z]+?);/, '&\1;')
      end

      node.children.each do |c|
        node.delete(c)
        c.remove
      end
      node.text = token
      completed += 1
    end
    total += 1

    [completed, total]
  end

  def merge_translations_to_android(txt, string_translations, languages)
    res = {}

    formatter = REXML::Formatters::Default.new

    languages.each do |language|

      translation_replacements = {}

      total = 0
      completed = 0

      begin
        doc = REXML::Document.new(txt)
      rescue REXML::ParseException => e
        Parsers.logger('Error parsing file with REXML', e)
        raise Parsers::ParseError, 'Not able to parse file, please contact support providing the uploaded file.'
      end

      doc.context[:attribute_quote] = :quote

      doc.elements.each do |entry|

        entry.elements.each('string') do |element|

          key = element.attributes['name']

          unless key.blank?
            completed, total = update_node_translation(key, element, language, string_translations, translation_replacements, completed, total)
          end

        end

        entry.elements.each('string-array') do |element|
          key = element.attributes['name']
          next if key.blank?
          idx = 1
          element.elements.each('item') do |item|

            item_key = key + '-' + idx.to_s
            completed, total = update_node_translation(item_key, item, language, string_translations, translation_replacements, completed, total)

            idx += 1
          end
        end

        entry.elements.each('plurals') do |element|
          key = element.attributes['name']
          element.elements.each('item') do |item|

            quantity = item.attributes['quantity']

            unless quantity.blank?
              item_key = key + '-' + quantity
              completed, total = update_node_translation(item_key, item, language, string_translations, translation_replacements, completed, total)
            end

          end
        end

      end

      t = ''
      formatter.write(doc, t)

      if !t.starts_with?('<?xml') && !t.starts_with?('﻿<?xml')
        t = '<?xml version="1.0" encoding="UTF-8"?>' + "\n" + t
      end

      segs = []
      cont = true
      pos = 0
      while cont
        idx = t.index(ICL_TOKEN, pos)
        if idx
          token = t[idx...idx + ICL_TOKEN.length + 32]
          translation = translation_replacements[token]
          segs << t[pos...idx]
          segs << if translation
                    translation
                  else
                    token
                  end
          pos = idx + token.length
        else
          segs << t[pos..-1]
          cont = false
        end
      end

      t = segs.join

      res[language] = [t, [total, completed]]

    end

    res

  end

  # ------------- new parsing ------------------

  def extract_texts_from_resource(lines, resource_format)
    texts = []

    parse_resource(lines, resource_format) do |name, txt, comment|
      # ignore our affiliate strings from the original resource file
      unless [ICL_CREDIT_TOKEN, ICL_AFFILIATE_URL_TOKEN].include?(name)
        texts << { token: truncate_name(name), text: txt, translation: txt, comments: comment }
      end
    end

    texts

  end

  def merge_translations_to_resource(lines, resource_format, languages, string_translations)
    separator = resource_format.separator_char
    multiline_char = resource_format.multiline_char
    label_delimiter = resource_format.label_delimiter
    text_delimiter = resource_format.text_delimiter
    end_of_line = resource_format.end_of_line
    comment_kind = resource_format.comment_kind

    res_lines = {}
    total = {}
    completed = {}
    languages.each do |lang|
      res_lines[lang] = []
      total[lang] = 0
      completed[lang] = 0
    end

    parse_resource(lines, resource_format) do |name, txt, comment|
      if comment
        languages.each do |lang|
          if comment_kind == COMMENT_KIND_IPHONE
            res_lines[lang] << "/* #{comment} */"
          elsif comment_kind == COMMENT_KIND_SQUARE_BRACKETS
            res_lines[lang] << "[ #{comment} ]"
          end
        end
      end

      add_translations(res_lines, total, completed, name, txt, languages, string_translations, separator, label_delimiter, text_delimiter, end_of_line)
    end

    line_break = ResourceFormat::LINE_BREAK_VAL[resource_format.line_break]

    translated_resources = {}
    languages.each do |language|
      translated_resources[language] = [res_lines[language].join(line_break), [total[language], completed[language]]]
    end
    translated_resources
  end

  SINGLE_QUOTE = "'".freeze
  DOUBLE_QUOTE = '"'.freeze

  STR_COMMON = 0
  STR_MULTILINE_COMMENT = 1
  STR_SINGLE_LINE_COMMENT = 2
  STR_QUOTED = 3

  PHASE_GET_NAME = 0
  PHASE_GET_TXT = 1

  def parse_resource(lines, resource_format)
    separator = resource_format.separator_char
    multiline_char = resource_format.multiline_char
    label_delimiter = resource_format.label_delimiter
    text_delimiter = resource_format.text_delimiter
    comment_kind = resource_format.comment_kind
    end_of_line = resource_format.end_of_line

    if comment_kind == COMMENT_KIND_IPHONE
      single_line_comment = '//'
      comment_begin = '/*'
      comment_end = '*/'
    elsif comment_kind == COMMENT_KIND_SQUARE_BRACKETS
      single_line_comment = nil
      comment_begin = '['
      comment_end = ']'
    else
      single_line_comment = nil
      comment_begin = nil
      comment_end = nil
    end

    phase = PHASE_GET_NAME
    str_mode = STR_COMMON
    str_escape = false # the previous char was an escape char and we ignore quotes
    str_continue_line = false # the previous char was a line-continue and we ignore EOL
    quote = nil # the quote char to close

    name = nil
    txt = nil
    comment = nil

    tail = ''
    accumulator = ''
    word = ''

    lines.each do |line_|
      # make sure that only a single \n appears at the end of the line
      line = line_.delete("\n").delete("\r")
      (line + "\n").each_char do |ch|
        if str_mode == STR_COMMON
          if ((ch == SINGLE_QUOTE) || (ch == DOUBLE_QUOTE)) && (((phase == PHASE_GET_NAME) && label_delimiter) || ((phase == PHASE_GET_TXT) && text_delimiter))
            str_mode = STR_QUOTED
            quote = ch
            word = ''
          elsif comment_begin && (tail[-comment_begin.length..-1] == comment_begin)
            str_mode = STR_MULTILINE_COMMENT
            comment = ''
          elsif single_line_comment && (tail[-single_line_comment.length..-1] == single_line_comment)
            str_mode = STR_SINGLE_LINE_COMMENT
            comment = ''
          end
        elsif str_mode == STR_MULTILINE_COMMENT
          if tail[-comment_end.length..-1] == comment_end
            # remove the comment close sequence
            comment = comment[0...-comment_end.length]
            str_mode = STR_COMMON
          else
            comment += ch
          end
        elsif str_mode == STR_SINGLE_LINE_COMMENT
          if !str_continue_line && (ch == "\n")
            str_mode = STR_COMMON
          else
            comment += ch
          end
        else
          if !str_escape && (ch == quote)
            str_mode = STR_COMMON
          else
            word += ch
          end
        end

        separator_check = if separator && (separator.length > 1) && (tail.length >= (separator.length - 1))
                            tail[(-separator.length + 1)..-1] + ch
                          else
                            ch
                          end

        if (phase == PHASE_GET_NAME) && (str_mode == STR_COMMON) && (separator_check == separator)
          name = quote ? word : accumulator
          accumulator = ''
          quote = nil
          phase = PHASE_GET_TXT
        elsif (str_mode == STR_COMMON) && !str_continue_line && (end_of_line && (phase == PHASE_GET_TXT) ? (ch == end_of_line) : (ch == "\n"))
          if phase == PHASE_GET_TXT
            txt = quote ? word : accumulator

            # if there's a line break in an unquoted string, make sure that it exists and remove it from the text
            if !text_delimiter && end_of_line
              txt = if txt[-end_of_line.length..-1] == end_of_line
                      txt[0...-end_of_line.length]
                    end
            end

            if !name.blank? && txt
              yield(name, txt, comment ? comment.strip : comment)
            end

            accumulator = ''
            quote = nil
            phase = PHASE_GET_NAME

            name = nil
            txt = nil
            comment = nil
          else
            accumulator = ''
          end

        elsif str_mode == STR_COMMON
          accumulator += ch
        end

        # keep the tail and limit its size
        tail += ch
        tail = tail[1..-1] if tail.length > 10

        str_continue_line = multiline_char && (ch == multiline_char)
        str_escape = (ch == '\\')
      end
    end
  end

  def extract_texts_from_yaml(txt, language)
    y = YAML.load(txt)
    if y.key?(language.iso)
      items = []
      recursive_yaml_parse(y[language.iso], [], items)
      return items
    end
    []
  end

  def recursive_yaml_parse(y, path, items)
    if y.class == Hash
      y.keys.each do |key|
        item = y[key]
        recursive_yaml_parse(item, path + [key], items)
      end
    elsif y.class == String
      items << [path.join('/'), y]
    end
  end

  def merge_translations_to_yaml(txt, language, _string_translations, _translation_languages_struct)
    y = YAML.load(txt)
    if y.key?(language.iso)

      items = []
      recursive_yaml_parse(y[language.iso], [], items)
      return items
    end
  end

  def truncate_name(name)
    if name.length <= MAX_STR_LENGTH
      str_token = name
    else
      name_sig = Digest::MD5.hexdigest(name)
      str_token = name[0...(MAX_STR_LENGTH - name_sig.length)] + name_sig
    end
    str_token
  end

end
