xml.support_tickets do
	for support_ticket in @support_tickets
		xml.support_ticket(:subject=>support_ticket.subject, :id=>support_ticket.id, :messages=>support_ticket.messages.length, :status=>support_ticket.status, :create_time=>support_ticket.create_time.to_i, :owner_type=>support_ticket.object_type, :owner_id=>support_ticket.object_id)
	end
end