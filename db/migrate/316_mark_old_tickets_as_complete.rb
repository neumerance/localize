class MarkOldTicketsAsComplete < ActiveRecord::Migration
	def self.up
		SupportTicket.where("create_time > '2012-1-1 00:00:00'").update_all(status:SUPPORT_TICKET_SOLVED)
	end
end
