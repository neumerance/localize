class AddDestLanguageToStats < ActiveRecord::Migration
	def self.up
		add_column :statistics, :dest_language_id, :integer
	end

	def self.down
		remove_column :statistics, :dest_language_id
	end
end
