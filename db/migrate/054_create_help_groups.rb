class CreateHelpGroups < ActiveRecord::Migration
	def self.up
		create_table( :help_groups, :options => 'ENGINE=InnoDB DEFAULT CHARSET=utf8') do |t|
			t.column :name, :string
			t.column :order, :int, :null => false, :default => 0
		end
	end

	def self.down
		drop_table :help_groups
	end
end
