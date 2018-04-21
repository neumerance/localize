class AddInviteStatusToOffer < ActiveRecord::Migration
	def self.up
		add_column :website_translation_contracts, :invited, :integer, :default=>0
		add_column :website_translation_offers, :invitation, :text
	end

	def self.down
		remove_column :website_translation_contracts, :invited
		remove_column :website_translation_offers, :invitation
	end
end
