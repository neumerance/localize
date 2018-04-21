class CreateResourceChats < ActiveRecord::Migration
	def self.up
		create_table( :resource_chats, :options => 'ENGINE=InnoDB DEFAULT CHARSET=utf8') do |t|
			t.column :translator_id, :int
			t.column :resource_language_id, :int
			t.column :status, :int
			t.column :need_notify, :int
			t.column :word_count, :int, :default=>0

			t.timestamps
		end
	end

	def self.down
		drop_table :resource_chats
	end
end
