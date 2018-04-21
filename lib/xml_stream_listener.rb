require 'rexml/document'
require 'rexml/streamlistener'
require 'xml_hierarcy_find'

class XmlStreamListener
  include REXML::StreamListener
  attr_reader :starts, :ends, :sentences, :word_count, :sentence_count, :document_count, :support_files, :original_languages, :support_files_to_translate, :tm_entries

  def initialize(revision, language_ids, logger = nil)
    @sentences = {}

    @word_count = {}
    @sentence_count = {}
    @document_count = {}
    @document_stat = {}

    @support_files = []
    @support_files_to_translate = {}
    @language_ids = language_ids

    @original_languages = []

    @support_file_stat = {}

    @tm_entries = {} # signature, from_language_id, to_language_id => orig, translation

    @revision = revision
    @expected_rev_id = revision.id
    @logger = logger

    @locators = []
    @text_find = create_locator(%w(TA_project ta_buffer translation sentences ta_sentence text_data text))
    @title_find = create_locator(%w(TA_project ta_buffer translation sentences ta_sentence marker_def html_marker attr ta_sentence text_data text))
    @support_files_find = create_locator(%w(TA_project ta_source_files support_files file name))
    @support_files_to_translate_find = create_locator(%w(TA_project ta_source_files support_files file translation text_data text))

    # initialize here too for mal formatted documents
    @found_completed_languages = {}

    @lang_cache = {}

    # initialize for the title text extractor
    @original_title = nil
    @title_original_lang_id = nil
    @original_title_stat = nil
    @found_completed_title_languages = {}

    @asian_languages = {}

    @nbsp = sprintf('%c', 0xC2) + sprintf('%c', 0xA0)
  end

  def create_locator(path)
    locator = XmlHierarcyFind.new(path)
    @locators << locator
    locator
  end

  def tag_start(name, attributes)
    @locators.each { |locator| locator.tag_start(name, attributes) }
  end

  def text(t)
    @last_text = t
  end

  def tag_end(name)
    t = @last_text || ''

    if @text_find.complete
      # TODO: XmlHierarcyFind now supports attribute to access by name and not index, should be easy to implement.
      original_lang_name = @text_find.attr_map[4]['original_language'].capitalize # <ta_sentence>
      lang_name = @text_find.attr_map[5]['language'].capitalize # <text_data>
      rev_id = @text_find.attr_map[6]['rev_id'].to_i # <text>
      do_translation = @text_find.attr_map[4]['do_translation'] == 'yes' # <ta_sentence>

      # find the IDs of these languages
      original_lang = fetch_lang(original_lang_name)
      lang = fetch_lang(lang_name)

      status = @text_find.attr_map[6]['status'].capitalize # <text>
      status_code = WORDS_STATUS[status]

      if original_lang && lang
        if (original_lang != lang) && (status_code == WORDS_STATUS_DONE_CODE)
          @found_completed_languages[lang.id] = t
        end

        if (lang == original_lang) && do_translation && (@expected_rev_id.nil? || (@expected_rev_id == rev_id))
          unless @original_languages.include?(original_lang)
            @original_languages << original_lang
          end

          # check if we're expecting a specific revision, and if so, if it matches
          # also check that we're checking text from the original language only
          # and, ignore blank sentences
          @original_text = t
          @original_lang_id = original_lang.id
          @original_stat = status_code

        end
      end
    end

    if @title_find.complete
      original_lang_name = @title_find.attr_map[8]['original_language'].capitalize
      lang_name = @title_find.attr_map[9]['language'].capitalize
      rev_id = @title_find.attr_map[10]['rev_id'].to_i
      do_translation = @title_find.attr_map[8]['do_translation'] == 'yes'

      # find the IDs of these languages
      original_lang = fetch_lang(original_lang_name)
      lang = fetch_lang(lang_name)

      status = @title_find.attr_map[10]['status'].capitalize
      status_code = WORDS_STATUS[status]

      if original_lang && lang
        if (original_lang != lang) && (status_code == WORDS_STATUS_DONE_CODE)
          @found_completed_title_languages[lang.id] = t
        end

        if (lang == original_lang) && do_translation && (@expected_rev_id.nil? || (@expected_rev_id == rev_id))
          unless @original_languages.include?(original_lang)
            @original_languages << original_lang
          end

          # check if we're expecting a specific revision, and if so, if it matches
          # also check that we're checking text from the original language only
          # and, ignore blank sentences
          @original_title = t
          @title_original_lang_id = original_lang.id
          @original_title_stat = status_code

        end
      end

    end

    if @support_files_find.complete
      @support_files << [Integer(@support_files_find.attr_map[3]['id']), t]
    end

    if @support_files_to_translate_find.complete
      if @support_files_to_translate_find.attr_map[5].key?('language') && @support_files_to_translate_find.attr_map[6].key?('status')
        lang_name = @support_files_to_translate_find.attr_map[5]['language']
        lang_id = fetch_lang(lang_name).id
        support_file_status = WORDS_STATUS[@support_files_to_translate_find.attr_map[6]['status']]
        @support_file_stat[lang_id] = support_file_status
      end
    end

    @last_text = nil

    had_complete = @text_find.complete(2)
    had_support_file_complete = @support_files_to_translate_find.complete(5)
    had_text_complete = @text_find.complete(5)
    had_title_complete = @title_find.complete(9)

    @locators.each { |locator| locator.tag_end(name) }

    if !@text_find.complete(5) && had_text_complete
      process_new_text(@original_lang_id, @original_text, @original_stat, @found_completed_languages)

      @original_text = nil
      @original_lang_id = nil
      @original_stat = nil
      @found_completed_languages = {}

    end

    if !@title_find.complete(9) && had_title_complete
      process_new_text(@title_original_lang_id, @original_title, @original_title_stat, @found_completed_title_languages)

      @original_title = nil
      @title_original_lang_id = nil
      @original_title_stat = nil
      @found_completed_title_languages = {}

    end

    if !@text_find.complete(2) && had_complete
      @document_stat.each do |lid, s|
        if !@document_count[lid].key?(s)
          @document_count[lid][s] = 1
        else
          @document_count[lid][s] += 1
        end
      end

      # initialize for the next document
      @document_stat = {}
    end

    if !@support_files_to_translate_find.complete(5) && had_support_file_complete
      if @support_files_to_translate_find.attr_map[4]['requires_translation'] == 'True'
        @support_file_stat.merge(0 => WORDS_STATUS_NEW_CODE).each do |language_id, sft|
          unless @support_files_to_translate.key?(language_id)
            @support_files_to_translate[language_id] = {}
          end

          if @support_files_to_translate[language_id].key?(sft)
            @support_files_to_translate[language_id][sft] += 1
          else
            @support_files_to_translate[language_id][sft] = 1
          end
        end
      end
      @support_file_stat = {} # initialize for the next support file
    end
  end

  def process_new_text(original_lang_id, original_text, original_stat, found_completed_languages)
    # ignore blank sentences
    if !original_text.blank? && original_lang_id && original_stat
      # we must check that the statistics have an entry for the original language
      @sentences[original_lang_id] = {} unless @sentences.key?(original_lang_id)

      t_sig = Digest::MD5.hexdigest(original_text)
      unique_sentence = !@sentences[original_lang_id].key?(t_sig)
      @sentences[original_lang_id][t_sig] = true if unique_sentence

      # check if we know how to handle this language
      unless @asian_languages.key?(original_lang_id)
        @asian_languages[original_lang_id] = Language.asian_language_ids.include?(original_lang_id)
      end

      # Do the word count

      if @revision.cms_request
        # icldev-82 block shortcodes retrieved from icl
        # @ ToDO Multiple queries are done when generating statistics
        #   ex. SELECT * FROM `website_shortcodes` WHERE (`website_shortcodes`.`shortcode_id` = 12 AND....
        shortcodes = @revision.cms_request.website.enabled_shortcodes

        atomic_shortcodes = shortcodes.select(&:atomic?).map(&:shortcode).join('|')
        atomic_regex = /(\[(#{atomic_shortcodes})\b(.*?)(?:(\/))?\])/i
        original_text.gsub! atomic_regex, ''

        # openclose - content should be translated
        openclose_shortcodes = shortcodes.select(&:openclose?).map(&:shortcode).join('|')
        openclose_regex = /(\[(#{openclose_shortcodes})\b(.*?)(?:(\/))?\]|\[\/(?:#{openclose_shortcodes})\])/i
        original_text.gsub! openclose_regex, ''

        # openclose exclude
        openclose_exclude_shortcodes = shortcodes.select(&:openclose_exclude?).map(&:shortcode).join('|')
        openclose_exclude_regex = /\[(#{openclose_exclude_shortcodes})\b(.*?)(?:(\/))?\](?:(.+?)\[\/\1)\]/i
        original_text.gsub! openclose_exclude_regex, ''

      end

      num_words = if @asian_languages[original_lang_id]
                    (original_text.gsub(@nbsp, ' ').tr('/', ' ').length / UTF8_ASIAN_WORDS).ceil
                  else
                    original_text.gsub(@nbsp, ' ').tr('/', ' ').split.length
                  end

      # ignore sentences with no text (almost like blank sentences)
      if num_words > 0
        # found_completed_languages.merge({original_lang_id=>nil}).each do |lang_id,translation|
        ([original_lang_id] + @language_ids).each do |lang_id|
          translation = found_completed_languages[lang_id]
          # puts "checking language: #{lang_id} => #{translation}"
          status_code = translation ? WORDS_STATUS_DONE_CODE : original_stat

          # don't add TM entries for the same language or that don't have translation
          if (lang_id != original_lang_id) && translation
            # check if we need to add to the TM. Process completed translations only
            tm_key = [t_sig, original_lang_id, lang_id]
            unless @tm_entries.key?(tm_key)
              @tm_entries[tm_key] = [original_text, translation, TU_COMPLETE]
            end

            if @tm_entries[tm_key][2] != TU_COMPLETE
              @tm_entries[tm_key][2] = TU_COMPLETE
            end
          end

          # make sure that we have the dictionary entries
          unless @sentence_count.key?(lang_id)
            @document_count[lang_id] = {}
            @sentence_count[lang_id] = {}
            @word_count[lang_id] = {}
          end

          unless @document_stat.key?(lang_id)
            @document_stat[lang_id] = WORDS_STATUS_DONE_CODE
          end

          unless @sentence_count[lang_id].key?(status_code)
            @word_count[lang_id][status_code] = 0
            @sentence_count[lang_id][status_code] = 0
          end

          # for each document, remember only the highest value status
          if @document_stat[lang_id] < status_code
            @document_stat[lang_id] = status_code
          end

          # count sentence any way
          @sentence_count[lang_id][status_code] += 1

          # ignore duplicate sentences for word count
          next unless unique_sentence
          @word_count[lang_id][status_code] += num_words

          # if (lang_id == 2) # && (status_code != WORDS_STATUS_DONE_CODE)
          #	puts "Language=#{lang_id} - Found status=#{status_code} - \"#{original_text}\" - #{num_words} words."
          # end
        end
      end
    end
  end

  def show_status_for_debug
    puts 'Results so far'
    @document_count.each do |k, v|
      v.each { |stat, cnt| puts "#{k}: #{WORDS_STATUS_TEXT[stat]} #{cnt} counts" }
    end
    @sentence_count.each do |k, v|
      v.each { |stat, cnt| puts "#{k}: #{WORDS_STATUS_TEXT[stat]} #{cnt} counts" }
    end
    @word_count.each do |k, v|
      v.each { |stat, cnt| puts "#{k}: #{WORDS_STATUS_TEXT[stat]} #{cnt} counts" }
    end
  end

  def fetch_lang(name)
    unless @lang_cache.key?(name)
      @lang_cache[name] = Language.where('name = ?', name).first
    end
    @lang_cache[name]
  end

end
