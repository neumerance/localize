class CreateWebsiteTranslationContracts < ActiveRecord::Migration
	def self.up
		create_table( :website_translation_contracts, :options => 'ENGINE=InnoDB DEFAULT CHARSET=utf8') do |t|
			t.column :website_translation_offer_id, :int			
			t.column :translator_id, :int
			t.column :status, :int
			t.timestamps
		end
	end

	def self.down
		drop_table :website_translation_contracts
	end
end
