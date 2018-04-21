class MarkCompletedTextResourceAsReviewed < ActiveRecord::Migration
	def self.up
		ResourceChat.where('translation_status = ?',RESOURCE_CHAT_TRANSLATION_COMPLETE).each do |resource_chat|
			resource_chat.update_attributes(:translation_status=>RESOURCE_CHAT_TRANSLATION_REVIEWED)
		end
	end

	def self.down
	end
end
