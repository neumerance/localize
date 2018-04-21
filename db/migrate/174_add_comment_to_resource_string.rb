class AddCommentToResourceString < ActiveRecord::Migration
	def self.up
		add_column :resource_strings, :comment, :text
		add_column :resource_formats, :comment_kind, :integer
	end

	def self.down
		remove_column :resource_strings, :comment
		remove_column :resource_formats, :comment_kind
	end
end
