class RenameUserLocale < ActiveRecord::Migration
	def self.up
		rename_column :users, :locale, :loc_code
	end

	def self.down
		rename_column :users, :loc_code, :locale
	end
end
