class AddOutputNameToResourceLanguage < ActiveRecord::Migration
	def self.up
		add_column :resource_languages, :output_name, :string
	end

	def self.down
		remove_column :resource_languages, :output_name
	end
end
