class FixStatusOfCompletedResourceChats < ActiveRecord::Migration
	def self.up
		cnt = 0
		ResourceChat.includes(:resource_language).where('resource_chats.translation_status = ?',RESOURCE_CHAT_TRANSLATION_COMPLETE).each do |rc|
			if !(rc.resource_language.managed_work && (rc.resource_language.managed_work.active == MANAGED_WORK_ACTIVE))
				rc.update_attributes(:translation_status=>RESOURCE_CHAT_TRANSLATOR_NEEDS_TO_REVIEW)
				cnt += 1
			end
		end
		puts "changed #{cnt} resource_chats from #{RESOURCE_CHAT_TRANSLATION_COMPLETE} to #{RESOURCE_CHAT_TRANSLATOR_NEEDS_TO_REVIEW}"
	end

	def self.down
	end
end
