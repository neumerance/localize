class CreateChats < ActiveRecord::Migration
	def self.up
		create_table(:chats, :options => 'ENGINE=InnoDB DEFAULT CHARSET=utf8') do |t|
			t.column :revision_id, :int
			t.column :translator_id, :int
			t.column :translator_has_access, :int
		end
	end

	def self.down
		drop_table :chats
	end
end
