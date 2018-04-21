class AddSampleTextToOffer < ActiveRecord::Migration
	def self.up
		add_column :website_translation_offers, :sample_text, :text
	end

	def self.down
		remove_column :website_translation_offers, :sample_text
	end
end
