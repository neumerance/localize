# encoding: utf-8
require 'rexml/document'

class REXML::Formatters::Default
  def write_element_content(node, output)
    # Monkey patch each attribute method to preserve order on element
    # attributes
    class << node.attributes
      alias_method :_each_attribute, :each_attribute
      # @ToDo this is raising a rubocop warning as method definitions 
      #   should not be nested. An exclude have been added to rubocop.yml
      def each_attribute(&b)
        to_enum(:_each_attribute).sort_by(&:name).each(&b)
      end
    end

    # If compact and all children are text, and if the formatted output
    # is less than the specified width, then try to print everything on
    # one line
    @level = 0
    string = ''
    old_level = @level
    @level = 0
    node.children.each { |child| write(child, string) }
    @level = old_level
    output << string
  end
end
