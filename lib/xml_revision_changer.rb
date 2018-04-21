require 'rexml/document'
require 'rexml/streamlistener'
require 'xml_hierarcy_find'

class XmlRevisionChanger
  include REXML::StreamListener
  attr_reader :result

  def initialize(proj_name, rev_name, new_rev_id, support_file_ids = {}, logger = nil)
    @logger = logger

    @locators = []
    @project_find = create_locator(['TA_project'])
    @text_find = create_locator(%w(TA_project ta_buffer translation sentences ta_sentence text_data text))
    @support_files_find = create_locator(%w(TA_project ta_source_files support_files file))

    @proj_name = proj_name
    @rev_name = rev_name
    @new_rev_id = new_rev_id
    @support_file_ids = support_file_ids

    @result = ''
  end

  def create_locator(path)
    locator = XmlHierarcyFind.new(path)
    @locators << locator
    locator
  end

  def tag_start(name, attributes)
    @locators.each { |locator| locator.tag_start(name, attributes) }

    if @project_find.complete
      attributes['name'] = @proj_name if attributes.key?('name')
      if attributes.key?('revision_name')
        attributes['revision_name'] = @rev_name
      end
    end

    if @text_find.complete && attributes.key?('rev_id')
      attributes['rev_id'] = @new_rev_id
    end

    if @support_files_find.complete && attributes.key?('id')
      id = attributes['id'].to_i
      change_to = if @support_file_ids.key?(id)
                    @support_file_ids[id]
                  else
                    @support_file_ids[@support_file_ids.keys[0]]
                  end
      attributes['id'] = change_to
    end

    @result += "<#{name}"
    attributes.each { |k, v| @result += " #{k}=\"#{v}\"" }
    @result += '>'
  end

  def tag_end(name)
    @locators.each { |locator| locator.tag_end(name) }
    @result += "</#{name}>"
  end

  def text(t)
    @result += t
  end

end
