class AddLockToResourceStrings < ActiveRecord::Migration
	def self.up
		add_column :string_translations, :lock_version, :int, :default=>0
	end

	def self.down
		remove_column :string_translations, :lock_version
	end
end
