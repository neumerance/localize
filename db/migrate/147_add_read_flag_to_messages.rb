class AddReadFlagToMessages < ActiveRecord::Migration
	def self.up
		add_column :messages, :is_new, :integer, :default=>1
	end

	def self.down
		remove_column :messages, :is_new
	end
end
