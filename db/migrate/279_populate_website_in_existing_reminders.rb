class PopulateWebsiteInExistingReminders < ActiveRecord::Migration
	def self.up
		cnt = 0
		Reminder.where(owner_type: 'WebsiteTranslationContract').each do |reminder|
			if reminder.owner && reminder.owner.website_translation_offer
				reminder.update_attributes!(:website_id=>reminder.owner.website_translation_offer.website_id)
				cnt += 1
			end
		end
		puts "Updated #{cnt} WebsiteTranslationContract reminders"
		
		cnt = 0
		Reminder.where(owner_type: 'Chat').each do |reminder|
			if reminder.owner && reminder.owner.revision && reminder.owner.revision.cms_request
				reminder.update_attributes!(:website_id=>reminder.owner.revision.cms_request.website_id)
				cnt += 1
			end
		end
		puts "Updated #{cnt} Chat reminders"
		
	end

	def self.down
	end
end
