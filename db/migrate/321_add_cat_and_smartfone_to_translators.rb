class AddCatAndSmartfoneToTranslators < ActiveRecord::Migration
	def self.up
		add_column :users, :cat, :boolean
		add_column :users, :smartphone, :boolean
	end

	def self.down
		remove_column :users, :cat
		remove_column :users, :smartphone
	end
end
