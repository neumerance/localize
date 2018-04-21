class AddCommentToMessage < ActiveRecord::Migration
	def self.up
		add_column :web_messages, :name, :text
		add_column :web_messages, :comment, :text
	end

	def self.down
		remove_column :web_messages, :name
		remove_column :web_messages, :comment
	end
end
