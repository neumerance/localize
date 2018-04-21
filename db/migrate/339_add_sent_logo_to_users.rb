class AddSentLogoToUsers < ActiveRecord::Migration
	def self.up
		add_column :users, :sent_logo, :boolean, :default => false
	end

	def self.down
		remove_column :users, :sent_logo
	end
end
