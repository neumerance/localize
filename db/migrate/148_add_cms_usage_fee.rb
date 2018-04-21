class AddCmsUsageFee < ActiveRecord::Migration
	def self.up
		add_column :website_translation_offers, :pay_per_use, :integer, :default=>0
		add_column :websites, :free_usage, :integer, :default=>0
	end

	def self.down
		remove_column :website_translation_offers, :pay_per_use
		remove_column :websites, :free_usage
	end
end
