class AddLanguagesToManagedWork < ActiveRecord::Migration
	def self.up
		add_column :managed_works, :from_language_id, :integer
		add_column :managed_works, :to_language_id, :integer
	end

	def self.down
		remove_column :managed_works, :from_language_id
		remove_column :managed_works, :to_language_id
	end
end
