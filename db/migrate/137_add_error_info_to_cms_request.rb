class AddErrorInfoToCmsRequest < ActiveRecord::Migration
	def self.up
		add_column :cms_requests, :error_description, :string
	end

	def self.down
		remove_column :cms_requests, :error_description
	end
end
