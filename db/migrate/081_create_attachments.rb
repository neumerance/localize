class CreateAttachments < ActiveRecord::Migration
	def self.up
		create_table( :attachments, :options => 'ENGINE=InnoDB DEFAULT CHARSET=utf8') do |t|
			t.column :message_id, :int

			t.column :content_type, :string
			t.column :filename, :string     
			t.column :size, :int
			t.column :parent_id, :int
		end
	end

	def self.down
		drop_table :attachments
	end
end
