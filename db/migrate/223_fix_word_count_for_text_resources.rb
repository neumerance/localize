class FixWordCountForTextResources < ActiveRecord::Migration
	def self.up
		resource_chats = ResourceChat.find_all_problems
		resource_chats.each do |rc|
			real_word_count = rc.real_word_count

			rc.update_attributes(:word_count=>real_word_count)
			puts "updated resource_chat.#{rc.id} to #{real_word_count}"
			
			if rc.resource_language.money_accounts.length == 1
				money_account = rc.resource_language.money_accounts[0]
				needed_balance = real_word_count * INSTANT_TRANSLATION_COST_PER_WORD
				if money_account.balance < needed_balance
					money_account.update_attributes(:balance=>needed_balance)
					puts "  --> also updated balance to #{needed_balance}"
				end
			end
		end
	end

	def self.down
	end
end
