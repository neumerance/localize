class AddRevisionUpdateCounter < ActiveRecord::Migration
	def self.up
		add_column :revisions, :update_counter, :integer, :default=>0
	end

	def self.down
		remove_column :revisions, :update_counter
	end
end
