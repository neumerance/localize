class AddKeyToCmsRequest < ActiveRecord::Migration
	def self.up
		add_column :cms_requests, :idkey, :string
		add_index :cms_requests, [:idkey], :name=>'idkey', :unique => false
	end

	def self.down
		remove_index :cms_requests, :name=>'idkey'
		remove_column :cms_requests, :idkey
	end
end
