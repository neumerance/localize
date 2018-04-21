class AddTranslatorLevel < ActiveRecord::Migration
	def self.up
		add_column :users, :level, :integer, :default=>NEW_TRANSLATOR
		add_index :users, [:level], :name=>'level', :unique=>false
	end

	def self.down
		remove_column :users, :level
	end
end
