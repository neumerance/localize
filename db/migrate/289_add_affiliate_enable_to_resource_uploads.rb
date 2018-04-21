class AddAffiliateEnableToResourceUploads < ActiveRecord::Migration
	def self.up
		add_column :resource_upload_formats, :include_affiliate, :integer
	end

	def self.down
		remove_column :remove_column, :include_affiliate
	end
end
