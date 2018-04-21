class CreateArbitrationOffers < ActiveRecord::Migration
	def self.up
		create_table(:arbitration_offers, :options => 'ENGINE=InnoDB DEFAULT CHARSET=utf8') do |t|
			t.column :arbitration_id, :int
			t.column :user_id, :int
			t.column :amount, :decimal, {:precision=>8, :scale=>2, :default=>0}
			t.column :status, :int			
		end
	end

	def self.down
		drop_table :arbitration_offers
	end
end
