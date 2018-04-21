class AddAppleStringsdictToResourceFormats < ActiveRecord::Migration
  def self.up
    name = 'Apple Stringsdict'
    return if ResourceFormat.find_by_name(name)

    ResourceFormat.create!({
      :name => name,
      :description => 'Apple Stringsdict File Format',
      :label_delimiter => nil,
      :text_delimiter => nil,
      :separator_char => '#',
      :multiline_char => nil,
      :end_of_line => nil,
      :comment_char => nil,
      :encoding => 1,
      :line_break => 0,
      :kind => 0
    })
  end

  def self.down
    ResourceFormat.find_by_name('Apple Stringsdict').delete
  end
end
