class CreatePrivateTranslators < ActiveRecord::Migration
	def self.up
		create_table( :private_translators, :options => 'ENGINE=InnoDB DEFAULT CHARSET=utf8') do |t|
			t.column :client_id, :int
			t.column :translator_id, :int
			t.column :status, :int

			t.timestamps
		end
	end

	def self.down
		drop_table :private_translators
	end
end
