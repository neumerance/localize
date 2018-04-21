class AddErrorResolution < ActiveRecord::Migration
	def self.up
		add_column :error_reports, :digest, :string
		add_column :error_reports, :resolution, :text
	end

	def self.down
		remove_column :error_reports, :digest
		remove_column :error_reports, :resolution
	end
end
