class AddIndexToCommErrors < ActiveRecord::Migration
	def self.up
		add_index :comm_errors, [:cms_request_id], :name=>'cms_request', :unique => false
	end

	def self.down
		remove_index :comm_errors, :name=>'cms_request'
	end
end
