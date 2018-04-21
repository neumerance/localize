class AddHtmlToCtl < ActiveRecord::Migration
	def self.up
		add_column :cms_target_languages, :html_output, :text
	end

	def self.down
		remove_column :cms_target_languages, :html_output
	end
end
