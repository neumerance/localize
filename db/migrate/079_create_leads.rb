class CreateLeads < ActiveRecord::Migration
	def self.up
		create_table( :leads, :options => 'ENGINE=InnoDB DEFAULT CHARSET=utf8') do |t|
			t.column :name, :string
			t.column :url, :string
			t.column :description, :string
			t.column :contact_title, :string
			t.column :contact_fname, :string
			t.column :contact_lname, :string
			t.column :contact_email, :string
			t.column :addr_country, :string
			t.column :addr_state, :string
			t.column :addr_city, :string
			t.column :addr_zip, :string
			t.column :addr_street, :string
			t.column :phone, :string

			t.column :what_they_do, :string
			t.column :word_count, :int
			
			t.column :text1, :string
			t.column :text2, :string
			t.column :text3, :string
			t.column :text4, :string
			
			t.column :status, :int, :default=>0
			t.column :advertisement_id, :int
			t.column :contact_id, :int
		end
end

def self.down
	drop_table :leads
	end
end
