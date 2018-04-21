class AddUserToLead < ActiveRecord::Migration
	def self.up
		add_column :leads, :user_id, :integer
		add_index :leads, [:user_id], :name=>'user', :unique=>true
		add_index :leads, [:advertisement_id], :name=>'advertisement', :unique=>false
	end

	def self.down
		remove_index :leads, :name=>'user'
		remove_index :leads, :name=>'advertisement'
		remove_column :leads, :user_id
	end
end
