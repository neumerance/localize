require 'zip/zip'

class ToolsController < ApplicationController
  prepend_before_action :setup_user_optional, only: [:new, :pre_create, :create, :select_to_languages]
  layout :determine_layout

  def index
    @header = _('Free Localization Tools')
  end

  def php_scanner
    @header = _('PHP Text Scanner and .po File Generator')
  end

  def create_po_from_php
    @header = _('Generated PO files')

    if params[:php_upload].blank?
      flash[:notice] = _('You must select the input files to scan')
      redirect_to action: :php_scanner
      return
    end

    php_upload_fname = params[:php_upload].original_filename

    orig_po = if !params[:po_upload].blank?
                scan_po(params[:po_upload])
              else
                {}
              end

    debug_php_code = []

    if get_ext(php_upload_fname) == 'zip'
      attachment = Attachment.create!(uploaded_data: params[:php_upload])
      zip = Zip::ZipFile.open(attachment.full_filename)
      gtcode = []
      zip.each do |entry|
        next if entry.directory?
        next unless %w(html htm php).include?(get_ext(entry.name))
        php_code = extract_php_code(zip.read(entry.name))
        debug_php_code += php_code
        gtcode += extract_gettext_code(php_code, entry.name)
      end
      attachment.destroy
    else
      page_txt = params[:php_upload].read
      php_code = extract_php_code(page_txt)
      gtcode = extract_gettext_code(php_code, params[:php_upload].original_filename)
      debug_php_code += php_code
    end

    domain_texts = {}
    gtcode.each do |args_entry|
      fname = args_entry[0]
      line = args_entry[1]
      description = args_entry[2]
      args = args_entry[3]
      next unless (args.length == 1) || (args.length == 2)
      txt = args[0]
      domain = args.length == 2 ? args[1] : 'default_extracted'
      domain_texts[domain] = {} unless domain_texts.key?(domain)
      domain_texts[domain][txt] = [] unless domain_texts[domain].key?(txt)
      entry = [fname, line, description]
      domain_texts[domain][txt] << entry unless domain_texts[domain][txt].include?(entry)
    end

    @temp_downloads = []
    @po_contents = {} # remember the uncompressed contents
    domain_texts.each do |domain, texts|
      po, line_count, word_count = create_po(texts, orig_po)

      temp_download = ToolDownload.create!(chgtime: Time.now,
                                           description: "PO file, generate from: '#{php_upload_fname}'. #{line_count} lines, #{word_count} words",
                                           filename: "#{domain}.po.gz",
                                           size: 1,
                                           content_type: 'application/octet-stream')

      temp_download.set_contents(po)
      @po_contents[temp_download] = po

      @temp_downloads << temp_download
    end

    if @temp_downloads.empty?
      flash[:notice] = _('Could not extract any texts.')
      redirect_to action: :php_scanner
    end
  rescue => e
    flash[:notice] = 'Something went wrong, please contact us.'
    redirect_to action: :php_scanner
  end

  def download_po
    tool_download = ToolDownload.find(params[:id].to_i)
    if tool_download.accesskey == params[:accesskey]
      send_file(tool_download.full_filename)
    end
  end

  # ----- Java resource extractor -----
  def java_resource_extractor
    @header = _('Java resource to spreadsheet converter')
    @delimiters = [['No delimiter', 0], ['Double quotes', 1], ['Single quotes', 2]]
  end

  def create_po_from_resource
    @header = _('Generated PO file')

    if params[:resource_upload].blank?
      flash[:notice] = _('You must select the input files to scan')
      redirect_to action: :java_resource_extractor
      return
    end

    resource_upload_fname = params[:resource_upload].original_filename

    orig_po = if !params[:po_upload].blank?
                scan_po(params[:po_upload])
              else
                {}
              end

    debug_php_code = []

    delimiter = params[:delimiter].to_i

    texts = extract_texts_from_resource(File.readlines(params[:resource_upload].path), resource_upload_fname, delimiter)

    if texts.empty?
      flash[:notice] = _('Could not extract any texts.')
      redirect_to action: :java_resource_extractor
    end

    po, line_count, word_count = create_po(texts, orig_po)

    ext_pos = resource_upload_fname.rindex('.')
    domain = if ext_pos
               resource_upload_fname[0...ext_pos]
             else
               resource_upload_fname
             end

    @po_contents = po

    @description = "PO file, generate from: '#{resource_upload_fname}'. #{line_count} lines, #{word_count} words"
    # create the download file
    @tool_download = ToolDownload.create!(chgtime: Time.now,
                                          description: @description,
                                          filename: "#{domain}.po.gz",
                                          size: 1,
                                          content_type: 'application/octet-stream')

    @tool_download.set_contents(po)
  rescue => e
    flash[:notice] = 'Something went wrong, please contact us.'
    redirect_to action: :java_resource_extractor
  end

  def java_resource_reconstructor
    @header = _('Create translated resource from .po')
    @encodings = [['UTF-8', 0], ['Java Unicode', 1]]
    @delimiters = [['No delimiter', 0], ['Double quotes', 1], ['Single quotes', 2]]
    @line_ends = [['Windows: \r\n', 0], ['Unix/Linux: \n', 1]]
  end

  def create_resource_from_po
    @header = _('Generated resource file')

    if params[:resource_upload].blank? || params[:po_upload].blank?
      flash[:notice] = _('You must select both PO and resource files to scan')
      redirect_to action: :java_resource_reconstructor
      return
    end

    resource_upload_fname = params[:resource_upload].original_filename
    po_fname = params[:po_upload].original_filename

    begin
      orig_po = scan_po(params[:po_upload])
    rescue => e
      Rails.logger.error e.message
      Rails.logger.error e.backtrace.join "\n"

      flash[:notice] = "Unfortunatelly we was not able to parse your file. This is our parser error message: #{e.message}. If you need support please contact us at support@icanlocalize.com"
      redirect_to action: :java_resource_reconstructor
      return
    end

    encoding = params[:outout_encoding].to_i
    delimiter = params[:delimiter].to_i
    line_end = params[:line_end].to_i

    @resource_txt = replace_texts_in_resource(File.readlines(params[:resource_upload].path), orig_po, encoding, delimiter, line_end)

    @description = "Resource file, generated from: '#{resource_upload_fname}' and '#{po_fname}'"
    # @temp_download = TempDownload.create!(:title=>"#{resource_upload_fname}.translated",
    #               :description=>"Resource file, generated from: '#{resource_upload_fname}' and '#{po_fname}'",
    #               :body=>resource_txt)

    @tool_download = ToolDownload.create!(chgtime: Time.now,
                                          description: @description,
                                          filename: "#{resource_upload_fname}.translated.gz",
                                          size: 1,
                                          content_type: 'application/octet-stream')
    @tool_download.set_contents(@resource_txt)

  end

  private

  def extract_php_code(page_txt_with_lb)
    page_txt = page_txt_with_lb.delete("\r")
    page_txt_lines = page_txt.split("\n")

    line_dic = {}
    idx = 1
    page_txt_lines.each do |line|
      stripped_line = line.delete("\n")
      line_dic[stripped_line] = idx
      idx += 1
    end

    php_code = []
    base = 0
    cont = true
    while cont
      start = page_txt.index('<?php', base)
      if start.nil?
        cont = false
      else
        fin = page_txt.index('?>', base)
        if fin.nil?
          cont = false
        else
          php = page_txt[(start + 5)...fin]

          line_end = page_txt.index("\n", start)
          line_begin = page_txt.rindex("\n", start) || -1
          if line_end && line_begin
            line = page_txt[line_begin + 1..line_end]
            stripped_line = line.delete("\n")
            line_num = line_dic[stripped_line]
          else
            line_num = nil
          end

          php_code << [line_num, php]
          base = fin + 2
        end
      end
    end
    php_code
  end

  def extract_gettext_code(php_code, fname)
    gtcode = []
    php_code.each do |line_data|
      base = 0
      cont = true
      while cont
        cont = false
        f = line_data[1]

        args, offset = get_func_args(f[base..-1], '__')
        if args && !args.empty?
          gtcode << [fname, line_data[0], 'Text in function', args]
          cont = true
          base += offset
        end

        eargs, offset = get_func_args(f[base..-1], '_e')
        if eargs && !eargs.empty?
          gtcode << [fname, line_data[0], 'Text in echo', eargs]
          cont = true
          base += offset
        end

        eargs, offset = get_func_args(f[base..-1], '_c')
        next unless eargs && !eargs.empty?
        gtcode << [fname, line_data[0], 'Text with context', eargs]
        cont = true
        base += offset
      end

    end
    gtcode
  end

  def get_func_args(str, func_name)
    fname_len = func_name.length + 1
    start = str.index(func_name + '(')
    if start.nil?
      return nil, 0
    else
      # get the internal strings
      args, offset = find_unstringed(str[start + fname_len..-1], ')')
      if args.nil?
        return nil, 0
      else
        return args, offset + start
      end
    end
  end

  def find_unstringed(str, exp)
    base = 0
    mode = 0 # 0 - outside, 1 - in double, 2 - in single

    args = []

    q_started = 0

    loop do
      m_fin = str.index(exp, base)
      m_d = str.index('"', base)
      m_s = str.index("'", base)
      m_c = str.index(',', base)

      # logger.info "mode=#{mode}, m_fin=#{m_fin}, m_s=#{m_s}, m_d=#{m_d}"

      if mode == 0
        if m_fin && (!m_d || (m_fin < m_d)) && (!m_s || (m_fin < m_s))
          return args, m_fin
        elsif m_d && (!m_s || (m_d < m_s))
          mode = 1
          base = m_d + 1
          q_started = base
        elsif m_s
          mode = 2
          base = m_s + 1
          q_started = base
        else
          return nil, 0
        end
      elsif (mode == 1) && m_d
        base = m_d + 1
        unless (m_d > 0) && (str[(m_d - 1)] == 92)
          mode = 0
          args << str[q_started...m_d]
        end
      elsif (mode == 2) && m_s
        base = m_s + 1
        unless (m_s > 0) && (str[(m_s - 1)] == 92)
          mode = 0
          args << str[q_started...m_s]
        end
      else
        return nil, 0
      end
    end
  end

  def create_po(texts, existing_translation)
    res = ''
    res += "msgid \"\"\n"
    res += "msgstr \"\"\n"
    res += "\"Content-Type: text/plain; charset=utf-8\\n\"\n"
    res += "\"Content-Transfer-Encoding: 8bit\\n\"\n"

    line_count = 0
    word_count = 0
    keys = texts.keys().sort
    keys.each do |txt|

      if existing_translation.key?(txt)
        msgstr = existing_translation[txt][0]
        comments = existing_translation[txt][1]
        flag = existing_translation[txt][2]
      else
        msgstr = ''
        comments = []
        flag = nil
      end

      locations = texts[txt]

      res += "\n"
      comments.each { |comment| res += "# #{comment.gsub('\\', '\\\\\\').gsub('"', '\"')}\n" }
      res += "#. #{locations[0][2]}\n"
      # references = (locations.collect { |l| "#{l[0]}:#{l[1]}"}).join(" ")
      # res += "#: #{references}\n"
      locations.each { |l| res += "#: #{l[0]}:#{l[1]}\n" }
      res += "#, #{flag}\n" unless flag.blank?

      # escape for the PO file
      msgid = txt.gsub('\\', '\\\\\\').gsub('"', '\"')
      msgstr = msgstr.gsub('\\', '\\\\\\').gsub('"', '\"')

      res += "msgid \"#{msgid}\"\n"
      res += "msgstr \"#{msgstr}\"\n"

      line_count += 1
      word_count += txt.split.length
    end
    [res, line_count, word_count]
  end

  def scan_po(po_file)
    res = {}

    comments = []
    flags = nil
    msgid = nil
    msgstr = nil

    mode = nil # 0 - not accumulating, 1 - in msgid, 2 - in msgstr
    File.readlines(po_file.path).each do |line_w_cr|
      line = line_w_cr.delete("\n").delete("\r")

      if line[0...2] == '# '
        mode = nil
        comment = line[2..-1]
        comment = comment.gsub('\"', '"').gsub('\\\\', '\\')
        comments << comment
      elsif line[0...2] == '#,'
        mode = nil
        flags = line[3..-1]
      elsif line[0...5] == 'msgid'
        mode = 'msgid'
        msgid = strip_quotes(line[6..-1])
        msgid = msgid.gsub('\"', '"').gsub('\\\\', '\\')
      elsif line[0...6] == 'msgstr'
        mode = 'msgstr'
        msgstr = strip_quotes(line[7..-1])
        msgstr = msgstr.gsub('\"', '"').gsub('\\\\', '\\')
      elsif line[0..0] == '"'
        val = strip_quotes(line)
        val = val.gsub('\"', '"').gsub('\\\\', '\\')

        if mode == 'msgid'
          msgid += val
        elsif mode == 'msgstr'
          msgstr += val
        end
      elsif line == ''
        res[msgid] = [msgstr, comments, flags] unless msgid.blank?

        mode = nil
        comments = []
        flags = nil
        msgid = nil
        msgstr = nil

      end
    end
    res
  end

  def strip_quotes(txt)
    txt[1...-1]
  end

  def get_ext(fname)
    ext_pos = fname.rindex('.')
    if ext_pos
      return fname[(ext_pos + 1)..-1]
    else
      return nil
    end
  end

  # --- .resource file processing ---
  def extract_texts_from_resource(lines, fname, delimiter)
    texts = {}
    region = nil
    idx = 0
    open_line = nil
    name = nil # make it global
    for line_ in lines
      idx += 1
      line = line_.delete("\n").delete("\r")
      eq_pos = line.index('=')
      if open_line
        txt = line
        txt = txt[1...-1] if delimiter != 0

        if line[-1..-1] == '\\'
          open_line += txt[0...-1]
        else
          open_line += txt
          entry = [fname, idx, name]
          texts[open_line] = [] unless texts.key?(open_line)
          texts[open_line] << entry unless texts[open_line].include?(entry)
          open_line = nil
        end
      elsif (line[0..0] == '[') && (line[-1..-1] == ']')
        region = line[1...-1]
      elsif !eq_pos.nil? && (eq_pos > 0) && (eq_pos < (line.length - 1))
        name = line[0...eq_pos]
        txt = line[(eq_pos + 1)..-1]
        txt = txt[1...-1] if delimiter != 0

        # check for multiline texts
        if line[-1..-1] == '\\'
          open_line = txt[0...-1]
        else
          entry = [fname, idx, name]
          texts[txt] = [] unless texts.key?(txt)
          texts[txt] << entry unless texts[txt].include?(entry)
        end
      end
    end
    texts
  end

  def replace_texts_in_resource(lines, po_texts, encoding, delimiter, line_end)
    res = []

    open_line = nil
    name = nil

    for line_ in lines
      line = line_.delete("\n").delete("\r")
      eq_pos = line.index('=')
      replacement = nil
      write_output = false

      if open_line
        if line[-1..-1] == '\\'
          open_line += line[0...-1]
        else
          open_line += line
          write_output = true
          replacement = replace_text(po_texts, name, open_line, delimiter, encoding)
          replacement = "#{name}=#{open_line}" unless replacement
          open_line = nil
        end
      elsif !eq_pos.nil? && (eq_pos > 0) && (eq_pos < (line.length - 1))
        name = line[0...eq_pos]
        txt = line[(eq_pos + 1)..-1]
        txt = txt[1...-1] if delimiter != 0
        if line[-1..-1] == '\\'
          open_line = txt[0...-1]
        else
          replacement = replace_text(po_texts, name, txt, delimiter, encoding)
          write_output = true
        end
      else
        write_output = true # comment line
      end
      res << (replacement ? replacement : line) if write_output
    end
    line_del = if line_end == 0
                 "\r\n"
               else
                 "\n"
               end
    res.join(line_del)
  end

  def replace_text(po_texts, name, txt, delimiter, encoding)
    replacement = nil
    if po_texts.key?(txt)
      translation = po_texts[txt][0]
      unless translation.blank?
        # add back the delimiter
        if delimiter == 1
          translation = '"' + translation + '"'
        elsif delimiter == 2
          translation = "'" + translation + "'"
        end
        if encoding == 1
          ords = utf8_dec(translation)
          u_trans = ''
          for ch in ords
            if ch < 0x80
              u_trans += ch.chr
            else
              hex = '%x' % ch
              hex = '0000'[0...(4 - hex.length)] + hex if hex.length < 4
              u_trans += "\\u#{hex}"
            end
          end
          translation = u_trans
        end
        replacement = "#{name}=#{translation}"
      end
    end
    replacement
  end

  def utf8_dec(txt)
    res = []
    cnt = 0
    buf = 0
    for idx in 0..txt.length
      o = txt[idx]
      if cnt == 0
        # not inside multi-byte sequence
        if (o & 0x80) == 0
          res << o
        elsif (o & 0xe0) == 0xc0
          cnt = 1
          buf = o & 0x1f
        elsif (o & 0xf0) == 0xe0
          cnt = 2
          buf = o & 0xf
        elsif (o & 0xf8) == 0xf0
          cnt = 3
          buf = o & 0x7
        end
      else
        buf = (buf << 6)
        buf += (o & 0x3f)
        cnt -= 1
        if cnt == 0
          res << buf
          buf = 0
        end
      end
    end
    res
  end

end
