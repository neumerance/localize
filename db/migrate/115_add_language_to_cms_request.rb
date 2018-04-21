class AddLanguageToCmsRequest < ActiveRecord::Migration
	def self.up
		add_column :cms_requests, :language_id, :integer
	end

	def self.down
		remove_column :cms_requests, :language_id
	end
end
