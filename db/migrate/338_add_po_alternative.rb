class AddPoAlternative < ActiveRecord::Migration
	def self.up
		ResourceFormat.create(:name => "PO alternative", :description => "alternative .po files. Please see details for more information", :separator_char => "=", :multiline_char => "\\", :encoding => 1, :line_break => 0)
	end

	def self.down
		ResourceFormat.find_by_name("PO alternative").destroy
	end
end

