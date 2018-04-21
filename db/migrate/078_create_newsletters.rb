class CreateNewsletters < ActiveRecord::Migration
	def self.up
		create_table( :newsletters, :options => 'ENGINE=InnoDB DEFAULT CHARSET=utf8') do |t|
			t.column :subject, :string
			t.column :body, :text
			t.column :flags, :int, :default=>0
			t.column :chgtime, :datetime
		end
	end

	def self.down
		drop_table :newsletters
	end
end
