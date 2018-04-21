class CreateAdvertisements < ActiveRecord::Migration
	def self.up
		create_table( :advertisements, :options => 'ENGINE=InnoDB DEFAULT CHARSET=utf8') do |t|
			t.column :title, :string		
			t.column :body, :text
		end
	end

	def self.down
		drop_table :advertisements
	end
end
