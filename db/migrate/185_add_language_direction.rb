class AddLanguageDirection < ActiveRecord::Migration
	def self.up
		add_column :languages, :rtl, :integer, :default=>0
	end

	def self.down
		remove_column :languages, :rtl
	end
end
