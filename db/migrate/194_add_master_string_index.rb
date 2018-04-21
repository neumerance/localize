class AddMasterStringIndex < ActiveRecord::Migration
	def self.up
		add_index :resource_strings, [:master_string_id], :name=>'master_string', :unique => false
	end

	def self.down
		remove_index :resource_strings, :name=>'master_string'
	end
end
