xml.reminders do
	@reminders.each do |reminder|
		xml.reminder(:id=>reminder.id, :message=>reminder.print_details(@user), :url=>url_for(reminder.link_to_handle(@user)), :can_delete=>reminder.user_can_delete)
	end
end
