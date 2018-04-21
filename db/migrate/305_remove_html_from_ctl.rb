class RemoveHtmlFromCtl < ActiveRecord::Migration
	def self.up
		remove_column :cms_target_languages, :html_output
	end
	
	def self.down
		add_column :cms_target_languages, :html_output, :text
	end
end
