class AddXmlItemKeyToResourceFormats < ActiveRecord::Migration
  def self.up
    name = 'XML item@key format'
    return if ResourceFormat.find_by_name(name)

    ResourceFormat.create({
      :name => name,
      :description => 'XML with ITEM elements and text to translate on "KEY" atrtibute',
      :label_delimiter => '//item',
      :text_delimiter => nil,
      :separator_char => 'key',
      :multiline_char => nil,
      :end_of_line => nil,
      :comment_char => nil,
      :encoding => 1,
      :line_break => 0,
      :kind => 5
    })
  end

  def self.down
    ResourceFormat.find_by_name('XML item@key format').delete
  end
end
