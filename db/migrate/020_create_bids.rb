class CreateBids < ActiveRecord::Migration
	def self.up
		create_table(:bids, :options => 'ENGINE=InnoDB DEFAULT CHARSET=utf8') do |t|
			t.column :chat_id, :int
			t.column :revision_language_id, :int
			t.column :status, :int

			t.column :amount, :decimal, {:precision=>8, :scale=>2, :default=>0}
			t.column :currency_id, :int	  
			t.column :accept_time, :datetime
		end
	end

	def self.down
		drop_table :bids
	end
end
