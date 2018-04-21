class CreateHelpTopics < ActiveRecord::Migration
	def self.up
		create_table( :help_topics, :options => 'ENGINE=InnoDB DEFAULT CHARSET=utf8') do |t|
			t.column :title, :string
			t.column :summary, :string
			t.column :url, :string
			t.column :display, :int, :null => false, :default => 0
		end
	end

	def self.down
		drop_table :help_topics
	end
end
