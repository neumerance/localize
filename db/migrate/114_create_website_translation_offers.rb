class CreateWebsiteTranslationOffers < ActiveRecord::Migration
	def self.up
		create_table(:website_translation_offers, :options => 'ENGINE=InnoDB DEFAULT CHARSET=utf8') do |t|
			t.column :website_id, :int
			t.column :from_language_id, :int
			t.column :to_language_id, :int
			
			t.column :amount, :decimal, {:precision=>8, :scale=>2, :default=>0}
			t.column :currency_id, :int	  

			t.timestamps
		end
	end

	def self.down
		drop_table :website_translation_offers
	end
end
