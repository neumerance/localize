require 'rexml/document'
require 'xml_hierarcy_find'

class ProjectLanguageAdder

  def initialize(fname_in)
    fin = open(fname_in, 'rb')
    @xml = REXML::Document.new(fin)
    fin.close
  end

  def add_languages(languages_to_add)
    root = @xml.root
    id = 1
    root.elements.each do |e|
      next unless e.name == 'ta_buffer'
      sentences = e.elements['translation'].elements['sentences']
      sentences.each do |sentence|
        # give IDs to sentences
        sentence.attributes['id'] = id
        id += 1

        # get the text data and duplicate to all other languages
        td = sentence.elements['text_data']
        languages_to_add.each do |lang|
          new_td = replicate_element(td)
          new_td.attributes['language'] = lang
          sentence << new_td
        end
      end
    end
  end

  def replicate_element(element)
    ne = REXML::Element.new(element)
    ne.text = element.text
    element.elements.each { |e| ne << replicate_element(e) }
    ne
  end

  def write(fname)
    f = open(fname, 'wb')
    f.write(@xml)
    f.close
  end

end
