class AddRegexCheckToTextResources < ActiveRecord::Migration
	def self.up
		add_column :text_resources, :check_standard_regex, :integer, :default=>1
	end

	def self.down
		remove_column :text_resources, :check_standard_regex
	end
end
