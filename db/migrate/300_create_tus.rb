class CreateTus < ActiveRecord::Migration
	def self.up
		create_table( :tus, :options => 'ENGINE=InnoDB DEFAULT CHARSET=utf8') do |t|
			t.column :client_id, :integer
			t.column :translator_id, :integer
			
			t.column :from_language_id, :integer
			t.column :to_language_id, :integer
			
			t.column :signature, :string
			
			t.column :owner_id, :integer
			t.column :owner_type, :string
			
			t.column :original, :text
			t.column :translation, :text

			t.column :status, :integer, :default=>TU_INCOMPLETE
			
			t.timestamps
		end
		add_index :tus, [:client_id], :name=>'client', :unique=>false
		add_index :tus, [:client_id, :from_language_id, :to_language_id], :name=>'client_languages', :unique=>false
		add_index :tus, [:client_id, :signature, :from_language_id, :to_language_id], :name=>'client_segment', :unique=>true		
	end

	def self.down
		drop_table :tus
	end
end
