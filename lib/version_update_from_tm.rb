require 'rexml/document'

class VersionUpdateFromTm
  def initialize(version, website, logger = nil)
    @version = version
    @tm_use_mode = website.tm_use_mode
    @tm_use_threshold = website.tm_use_threshold
    @user = version.revision.project.client
    @logger = logger
    @language_ids = {}
  end

  def read
    @doc = REXML::Document.new(@version.get_contents)
  end

  def read_data(dat)
    @doc = REXML::Document.new(dat)
  end

  def update_languages(languages)
    @doc.elements.each('TA_project/ta_buffer') do |ta_buffer|
      orig_language = ta_buffer.attributes['original_language']
      ta_buffer.elements.each('translation/sentences/ta_sentence') do |sentence|

        # complete the text in the sentence
        complete_text_for_sentence(sentence, orig_language, languages)

        # complete the text in the title attributes
        sentence.elements.each('marker_def/html_marker/attr/ta_sentence') do |title_sentence|
          complete_text_for_sentence(title_sentence, orig_language, languages)
        end
      end
    end
  end

  def complete_text_for_sentence(sentence, orig_language, languages)
    orig_lang_buffer = nil
    found_languages = {}
    sentence.elements.each('text_data') do |text_data|
      lang = text_data.attributes['language']
      if lang == orig_language
        orig_lang_buffer = text_data
      else
        found_languages[lang] = text_data
      end
    end

    return unless orig_lang_buffer

    original = nil
    orig_lang_buffer.elements.each('text') do |text_element|
      original = text_element.text
    end

    return unless original

    t_sig = Digest::MD5.hexdigest(original)

    languages.each do |lang|
      # check if translation exists
      # puts "searching for TU t_sig=#{t_sig}, from_language_id=#{language_id(orig_language)}, to_language_id=#{language_id(lang)}, "
      tu = @user.tus.where('(signature=?) AND (from_language_id=?) AND (to_language_id=?) AND (status=?)', t_sig, language_id(orig_language), language_id(lang), TU_COMPLETE).first
      if !tu && @user.reverse_tm?
        tu = @user.tus.where('(signature=?) AND (to_language_id=?) AND (from_language_id=?) AND (status=?)', t_sig, language_id(orig_language), language_id(lang), TU_COMPLETE).first
      end

      next unless tu
      if found_languages.key?(lang)
        merge_text_data_with_tm(found_languages[lang], tu)
      else
        # duplicate the original language
        text_data = orig_lang_buffer.deep_clone
        text_data.attributes['language'] = lang
        # add to the XML
        sentence.elements << text_data

        # complete it
        merge_text_data_with_tm(text_data, tu)
      end
    end
  end

  def merge_text_data_with_tm(text_data, tu)
    has_markers = false
    text_data.elements.each('marker') { |_marker| has_markers = true }

    text_data.elements.each('text') do |text|
      # don't change already-completed sentences
      next unless text.attributes['status'] != 'Complete'
      text.attributes['from_TM'] = 'True'
      begin
        text_length = text.text.split.length
      rescue
        text_length = 0
      end

      text.attributes['status'] = !has_markers && (@tm_use_mode == TM_COMPLETE_MATCHES) && (text_length >= @tm_use_threshold) ? 'Complete' : 'Modified'
      begin
        text.text = tu.translation
      rescue
        if @logger
          @logger.info "------ TU merge problem. Cannot write text for tu.#{id}"
        end
      end
    end
  end

  def write(where)
    formatter = REXML::Formatters::Default.new
    formatter.write(@doc, where)
  end

  def language_id(language_name)
    unless @language_ids.key?(language_name)
      language = Language.where('name=?', language_name).first
      @language_ids[language_name] = (language ? language.id : nil)
    end
    @language_ids[language_name]
  end

end
