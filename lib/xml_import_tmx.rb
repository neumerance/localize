require 'rexml/document'
require 'rexml/streamlistener'
require 'xml_hierarcy_find'

class XmlImportTmx
  include REXML::StreamListener
  attr_reader :result

  DEBUG = false

  def initialize(logger = nil)
    @logger = logger

    @locators = []
    @body_find = create_locator(%w(tmx body))
    @tu_find = create_locator(%w(tmx body tu))
    @tuv_find = create_locator(%w(tmx body tu tuv))
    @seg_find = create_locator(%w(tmx body tu tuv seg))
    @ut_find = create_locator(%w(tmx body tu tuv seg ut))

    @languages_cache = {}

  end

  def create_locator(path)
    locator = XmlHierarcyFind.new(path)
    @locators << locator
    locator
  end

  def tag_start(name, attributes)
    @locators.each { |locator| locator.tag_start(name, attributes) }

    if @tu_find.complete
      @orig_language = nil
      @orig_text = nil
      @translations = {}
    end

    if @tuv_find.complete
      lang_code = attributes['xml:lang']
      language = find_language(lang_code)
      @logger.info "TUV start => #{lang_code} -> #{language ? language.name : 'cannot find language'}" if @logger
    end

    @logger.info "--- Start: #{name} with #{(attributes.collect { |k, v| "#{k}=>#{v}" }).join(',')}" if @logger

  end

  def tag_end(name)
    @locators.each { |locator| locator.tag_end(name) }
    @logger.info "--- End: #{name}" if @logger
  end

  def text(t)
    @logger.info "----- Text: #{t}" if @logger
  end

  def find_language(lang_code)
    return @languages_cache[lang_code] if @languages_cache.key?(lang_code)

    if (lang_code == 'ZH-TW') || (lang_code == 'ZH-HK')
      iso = 'zh-Hant'
    elsif (lang_code == 'ZH.TRA') || (lang_code == 'ZH-CN')
      iso = 'zh-Hans'
    elsif lang_code == 'PT-BR'
      iso = 'pt-BR'
    elsif lang_code == 'PT-PT'
      iso = 'pt-PT'
    else
      sep_idx = lang_code.index('-')
      iso = if sep_idx && (sep_idx > 0)
              lang_code[0...sep_idx]
            else
              lang_code
            end
      iso = iso.downcase
    end

    @logger.info "------- looking for language #{iso}" if DEBUG

    lang = Language.where('iso=?', iso).first
    if DEBUG
      if lang
        @logger.info "----> got #{lang.name}"
      else
        @logger.info '----> got nothing'
      end
    end

    @languages_cache[lang_code] = lang
    lang
  end

end
