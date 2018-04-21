class XmlHierarcyFind

  attr_reader :level, :last_match_num, :attr_map, :attributes

  def initialize(hierarcy)
    @seek = hierarcy
    @level = 0
    @last_match_num = 0
    @attr_map = {} # xml node attributes, key is the hierarchy level. 0 is root node 7 is very inner node
    @attributes = {} # xml node attributes where key is the xml tag name, not used
  end

  def tag_start(name, attributes)
    if (@last_match_num == @level) && (name == @seek[@level])
      @last_match_num += 1
      attr_map[level] = attributes
      @attributes[name] = attributes
    end
    @level += 1
  end

  def tag_end(_name)
    @last_match_num -= 1 if @last_match_num == @level
    @level -= 1
  end

  def complete(length = nil)
    (@level == @last_match_num) && # if we dont have children open
      (@last_match_num == (length || @seek.length))
  end

end
