class AddRevisionIstest < ActiveRecord::Migration
	def self.up
		add_column :revisions, :is_test, :integer, :default=>0
	end

	def self.down
		remove_column :revisions, :is_test
	end
end
