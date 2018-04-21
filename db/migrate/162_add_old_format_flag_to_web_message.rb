class AddOldFormatFlagToWebMessage < ActiveRecord::Migration
	def self.up
		add_column :web_messages, :old_format, :integer, :default=>0
	end

	def self.down
		remove_column :web_messages, :old_format
	end
end
