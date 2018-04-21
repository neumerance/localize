class SetDeliveredValue < ActiveRecord::Migration
	def self.up
		CmsRequest.record_timestamps = false
		CmsRequest.where('(delivered IS NULL) AND (status IN (?))',[CMS_REQUEST_TRANSLATED,CMS_REQUEST_DONE]).each do |c|
			c.update_attributes(:delivered=>1)
		end
		CmsRequest.record_timestamps = true
	end

	def self.down
	end
end
