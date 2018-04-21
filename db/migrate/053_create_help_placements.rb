class CreateHelpPlacements < ActiveRecord::Migration
	def self.up
		create_table( :help_placements, :options => 'ENGINE=InnoDB DEFAULT CHARSET=utf8') do |t|
			t.column :controller, :string
			t.column :action, :string
			t.column :user_match, :int
			t.column :help_group_id, :int
			t.column :help_topic_id, :int
		end
	end

	def self.down
		drop_table :help_placements
	end
end
