class CreateIdentityVerifications < ActiveRecord::Migration
	def self.up
		create_table( :identity_verifications, :options => 'ENGINE=InnoDB DEFAULT CHARSET=utf8') do |t|
			# who the verification belongs to
			t.column :normal_user_id, :int
			
			# what is verified
			t.column :verified_item_type, :string
			t.column :verified_item_id, :int
			
			# verification
			t.column :chgtime, :datetime
			t.column :status, :int, :default=>0
			
		end
	end

	def self.down
		drop_table :identity_verifications
	end
end
