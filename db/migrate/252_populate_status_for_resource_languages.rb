class PopulateStatusForResourceLanguages < ActiveRecord::Migration
	def self.up
		ResourceLanguage.all.each do |resource_language|
			if resource_language.selected_chat
				resource_language.update_attributes(:status=>RESOURCE_LANGUAGE_CLOSED)
			end
		end
	end

	def self.down
	end
end
