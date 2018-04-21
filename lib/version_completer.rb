require 'rexml/document'

class VersionCompleter
  def initialize(version, logger = nil)
    @version = version
    @logger = logger
  end

  def read
    # replace unmatched & with escaped version
    content = @version.get_contents.gsub!(/&(?!(?:amp|lt|gt|quot|apos);)/, '&amp;')
    @doc = REXML::Document.new(content)
  end

  def read_data(dat)
    @doc = REXML::Document.new(dat)
  end

  def complete_languages(languages)
    formatter = REXML::Formatters::Default.new

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
        found_languages[lang] = true
        complete_text_data(text_data)
      end
    end

    languages.each do |lang|
      next if found_languages.key?(lang)
      # duplicate the original language
      text_data = orig_lang_buffer.deep_clone
      sentence.elements << text_data

      # complete it
      complete_text_data(text_data, lang)

      # t = ''
      # formatter.write(text_data,t) # text_data.write(t)
      # puts "duplicated to #{lang}: #{t}"
    end
  end

  def complete_text_data(text_data, lang = nil)
    if lang
      text_data.attributes['language'] = lang
      named_lang = lang
    else
      named_lang = text_data.attributes['language']
    end
    text_data.elements.each('text') do |text|
      text.attributes['status'] = 'Complete'
      begin
        txt = text.text.blank? ? '' : text.text
        new_val = named_lang + ':' + txt
        text.text = new_val
      rescue
        if @logger
          txt = ''
          formatter = REXML::Formatters::Default.new
          formatter.write(text_data, txt)
          @logger.info "------ XML PROBLEM. Language: |#{lang}|. NULL TEXT FOR:\n#{txt}\n"
        end
      end
    end
  end

  def write(where)
    content = ''
    formatter = REXML::Formatters::Default.new

    formatter.write(@doc, content)
    content.gsub!('&amp;', '&')

    where << content
  end
end
