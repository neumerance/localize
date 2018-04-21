class AddXliffToResourceFormats < ActiveRecord::Migration
  def self.up
    return if ResourceFormat.find_by_name('Xliff')

    ResourceFormat.reset_column_information
    ResourceFormat.create({
      :name => "Xliff",
      :description => "Xliff Resource File",
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
    ResourceFormat.find_by_name('Xliff').delete
  end
end
