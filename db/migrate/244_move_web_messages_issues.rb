class MoveWebMessagesIssues < ActiveRecord::Migration
	def self.up
		issues_cnt = 0
		messages_cnt = 0
		WebMessage.all.each do |m|
			WebMessage.transaction do
				if (m.messages.length > 0) && (m.owner.class == Client) && (m.translator)
					issue = Issue.new(:title=>'Help needed',
									:initiator_id=>m.owner.id,
									:target_id=>m.translator.id,
									:kind=>ISSUE_INCORRECT_TRANSLATION,
									:status=>((m.translation_status == TRANSLATION_NEEDS_EDIT) ? ISSUE_OPEN : ISSUE_CLOSED))
					issue.owner = m
					issue.save!
					
					issues_cnt += 1
					
					m.messages.each do |message|
						message.owner = issue
						message.save!
						messages_cnt += 1
					end
					
					m.update_attributes!(:translation_status=>TRANSLATION_COMPLETE)
				end
			end
		end
		puts "--- web_messages issue migration: created #{issues_cnt} issues and moved #{messages_cnt} messages."
	end

	def self.down
	end
end
