class AddPrivateModeToRl < ActiveRecord::Migration
	def self.up
		add_column :revision_languages, :no_bidding, :integer, :default=>0
	end

	def self.down
		remove_column :revision_languages, :no_bidding
	end
end
