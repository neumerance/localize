require 'rexml/document'
require 'rexml/streamlistener'
require 'xml_hierarcy_find'

class SisulizerScanner
  include REXML::StreamListener
  attr_reader :orig_language, :word_count, :target_languages

  ROW_IGNORE_IDS = %w(Left Top Width Height Right Bottom).freeze

  DEBUG = true

  def initialize(logger = nil)
    @word_count = {} # from-lang: { [to-lang, status] : count }
    @total_orig_words = {}

    @hierarchy = []
    @logger = logger
    @curitem = nil

    @languages_cache = {}

    @orig_language = nil
    @asign_orig_language = nil

    @target_languages = {}
    @scanning = false
    @in_row = false
  end

  def sis_lang_decode(lang_code)
    return @languages_cache[lang_code] if @languages_cache.key?(lang_code)

    if (lang_code == 'zh') || (lang_code == 'zh-TW') || (lang_code == 'zh-HK')
      iso = 'zh-Hant'
    elsif (lang_code == 'zh.tra') || (lang_code == 'zh-CN')
      iso = 'zh-Hans'
    elsif (lang_code == 'pt-BR') || (lang_code == 'pt-PT')
      iso = lang_code
    elsif (lang_code == 'no') || (lang_code == 'nb')
      iso = 'nb'
    else
      sep_idx = lang_code.index('-')
      iso = if sep_idx && (sep_idx > 0)
              lang_code[0...sep_idx]
            else
              lang_code
            end
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

  def count_words(to_lang, status, t)
    # decode the Sisulizer text encoding
    t = t.gsub('##', '#').gsub('#t', ' ').gsub('#l', ' ').gsub('#c', ' ').tr('/', ' ')

    num_words = if @asign_orig_language
                  (t.length / UTF8_ASIAN_WORDS).ceil
                else
                  t.split.length
                end

    @word_count[to_lang] = {} unless @word_count.key?(to_lang)

    @word_count[to_lang][status] = 0 unless @word_count[to_lang].key?(status)

    @word_count[to_lang][status] += num_words
  end

  def tag_start(name, attributes)
    @hierarchy << [name, attributes]

    if @hierarchy.length == 2
      if (@hierarchy[0][0] == 'document') && (@hierarchy[1][0] == 'lang')
        if @hierarchy[1][1].key?('id')
          lang_name = @hierarchy[1][1]['id']
          language = sis_lang_decode(lang_name)
          if language
            @target_languages[language] = true
            @logger.info "----- adding translation language #{language.name}" if DEBUG
          end
        end
      elsif (@hierarchy[0][0] == 'document') && (@hierarchy[1][0] == 'source')
        if @hierarchy[1][1].key?('original')
          lang_name = @hierarchy[1][1]['original']
          language = sis_lang_decode(lang_name)
          doc_name = @hierarchy[1][1]['name']

          if language
            if @orig_language.nil?
              # set the original language
              @orig_language = language

              # check if it's an Asian language
              @asign_orig_language = Language.asian_language_ids.include?(@orig_language.id)

              @logger.info "----- set original language #{language.name}" if DEBUG
            end

            if @orig_language == language
              @logger.info "----- scanning document #{doc_name}" if DEBUG
              @scanning = true
            else
              @logger.info "----- ++++ Ignoring document #{doc_name} with language #{language.name}" if DEBUG
            end
          end
        end
      end
    elsif (@hierarchy.length > 2) && (@hierarchy[-1][0] == 'row') &&
          !@hierarchy[-1][1].key?('excluded') &&	!@hierarchy[-1][1].key?('locked') &&
          !ROW_IGNORE_IDS.include?(@hierarchy[-1][1]['id'])
      @in_row = true
      @row_with_text = false
      @row_translations = []
      @orig_text = nil
    end
  end

  def tag_end(_name)
    closed_tag = @hierarchy.pop

    # add all the translations
    if closed_tag[0] == 'row'
      @logger.info "-- Closing row (#{@row_translations.length} items)--" if DEBUG
      if @orig_text && !@row_with_text
        # make a list of all the languages to expect
        missing_languages = @target_languages.keys.collect { |k| k }
        @row_translations.each do |row_translation|
          count_words(row_translation[0], row_translation[1], @orig_text)
          missing_languages.delete(row_translation[0])
        end

        # make sure that if any language doesn't appear for that row, it's still counted
        missing_languages.each do |missing_language|
          count_words(missing_language, WORDS_STATUS_NEW_CODE, @orig_text)
        end
      end
      @in_row = false
    end

    @scanning = false if @hierarchy.length == 1
  end

  def text(t)
    return if !@scanning || t.blank?

    @logger.info "\n>>> hierarchy: #{(@hierarchy.collect { |h| h[0] }).join(' > ')}" if DEBUG

    if @in_row
      if @hierarchy[-1][0] == 'row'
        count_words(nil, WORDS_STATUS_NEW_CODE, t)
        @row_with_text = true
        @logger.info " ---- row without translation: #{t}" if DEBUG
      elsif @hierarchy[-1][0] == 'native'
        @orig_text = t
        @logger.info " ---- native text: #{t}" if DEBUG
      elsif (@hierarchy[-1][0] == 'lang') && @hierarchy[-1][1].key?('id')
        lang_code = @hierarchy[-1][1]['id']
        lang_status = (@hierarchy[-1][1]['status'] || '5').to_i
        translation_status = lang_status == 5 ? WORDS_STATUS_DONE_CODE : WORDS_STATUS_MODIFIED_CODE
        dest_language = sis_lang_decode(lang_code)
        if dest_language
          @logger.info " ---- translation to #{dest_language.name}: #{t}" if DEBUG
          @row_translations << [dest_language, translation_status]
        else
          @logger.info " ----- can't find language #{lang_code}" if DEBUG
        end
      end
    end
  end

  # this will add all the languages to 'nil' to all existing languages
  def fixup_count

    # step 1: make sure that all destination languages exist
    @target_languages.each do |to_lang, _v|
      unless @word_count.key?(to_lang)
        @word_count[to_lang] = { WORDS_STATUS_NEW_CODE => 0 }
      end
    end

    # step 2: check if there's any nil to-language and spread it on all the to-languages
    if @word_count.key?(nil)
      # this is the word count that needs to spread to all languages
      words_to_add = @word_count[nil][WORDS_STATUS_NEW_CODE]

      # add it to the rest of the entries which are not nil
      @word_count.each do |to_lang, _stats|
        next unless to_lang
        unless @word_count[to_lang].key?(WORDS_STATUS_NEW_CODE)
          @word_count[to_lang][WORDS_STATUS_NEW_CODE] = 0
        end
        @word_count[to_lang][WORDS_STATUS_NEW_CODE] += words_to_add
      end

      # and delete the nil entry
      @word_count.delete(nil)
    end

  end

end
