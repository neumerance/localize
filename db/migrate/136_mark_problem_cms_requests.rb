class MarkProblemCmsRequests < ActiveRecord::Migration
	def self.up
		CmsRequest.where('status IN (?)',[CMS_REQUEST_WAITING_FOR_PROJECT_CREATION, CMS_REQUEST_PROJECT_CREATION_REQUESTED, CMS_REQUEST_CREATING_PROJECT]).each do |c|
			c.update_attributes!(:last_operation=>LAST_TAS_COMMAND_CREATE, :pending_tas=>1)
		end
	end

	def self.down
	end
end
