class CreateFeedbacks < ActiveRecord::Migration
	def self.up
		create_table( :feedbacks, :options => 'ENGINE=InnoDB DEFAULT CHARSET=utf8') do |t|
			t.integer :client_id
			
			t.integer :owner_id
			t.string :owner_type
			
			t.string :company
			t.string :title
			t.string :url
			
			t.text :txt

			t.integer :showall
			
			t.timestamps
		end
	end

	def self.down
		drop_table :feedbacks
	end
end
