class CreateCommErrors < ActiveRecord::Migration
	def self.up
		create_table( :comm_errors, :options => 'ENGINE=InnoDB DEFAULT CHARSET=utf8') do |t|
			t.column :cms_request_id, :int
			t.column :status, :int
			t.column :error_code, :int
			t.column :error_description, :string
			t.timestamps
		end
	end

	def self.down
		drop_table :comm_errors
	end
end
