class PopulateResourceUploadFormats < ActiveRecord::Migration
	def self.up
		TextResource.all.each do |text_resource|
			text_resource.resource_uploads.each do |resource_upload|
				if resource_upload.resource_upload_format == nil
					resource_upload_format = ResourceUploadFormat.new
					resource_upload_format.resource_upload = resource_upload
					resource_upload_format.resource_format = text_resource.resource_format
					resource_upload_format.save!
				end
			end
		end
	end

	def self.down
		text_resource.resource_uploads.each do |resource_upload|
			if resource_upload.resource_upload_format
				resource_upload.resource_upload_format.destroy
			end
		end
	end
end
