class CreatePaypalMockReplies < ActiveRecord::Migration
	def self.up
		create_table( :paypal_mock_replies, :options => 'ENGINE=InnoDB DEFAULT CHARSET=utf8') do |t|
			t.column :txn_id, :string

			t.column :last_name, :string
			t.column :receiver_email, :string
			t.column :payment_status, :string
			t.column :payment_gross, :string
			t.column :tax, :string
			t.column :residence_country, :string
			t.column :address_state, :string
			t.column :payer_status, :string
			t.column :txn_type, :string
			t.column :address_country, :string
			t.column :payment_date, :string
			t.column :first_name, :string
			t.column :item_name, :string
			t.column :address_street, :string
			t.column :address_name, :string
			t.column :item_number, :string
			t.column :receiver_id, :string
			t.column :business, :string
			t.column :payer_id, :string
			t.column :address_zip, :string
			t.column :payment_fee, :string
			t.column :address_country_code, :string
			t.column :address_city, :string
			t.column :address_status, :string
			t.column :receipt_id, :string
			t.column :mc_fee, :string
			t.column :mc_currency, :string
			t.column :payer_email, :string
			t.column :payment_type, :string
			t.column :mc_gross, :string
			t.column :invoice, :string
		end
		add_index :paypal_mock_replies, [:txn_id], :name=>'txn_id', :unique => true
	end

	def self.down
		drop_table :paypal_mock_replies
	end
end
