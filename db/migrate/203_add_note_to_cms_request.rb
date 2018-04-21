class AddNoteToCmsRequest < ActiveRecord::Migration
	def self.up
		add_column :cms_requests, :note, :text
	end

	def self.down
		remove_column :cms_requests, :note
	end
end
