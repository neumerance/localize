class AddTranslatorsRateAndCapacity < ActiveRecord::Migration
	def self.up
		add_column :users, :capacity, :integer
		add_column :users, :rate, :decimal, {:precision=>8, :scale=>2, :default=>0}
	end

	def self.down
		remove_column :users, :capacity
		remove_column :users, :rate
	end
end
