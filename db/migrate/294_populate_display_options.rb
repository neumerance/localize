class PopulateDisplayOptions < ActiveRecord::Migration
	def self.up
		Client.all.each do |client|
			display_options = 0
			
			if client.web_supports.length > 0
				display_options += DISPLAY_WEB_SUPPORTS
			end
			
			if client.invitation && (client.invitation.active == 1)
				display_options += DISPLAY_AFFILIATE
			end
			
			if display_options != 0
				client.update_attributes(:display_options=>display_options)
			end
			
		end
	end

	def self.down
	end
end
