module RemindersHelper

  def reminder_event_link(reminder, user)
    link = reminder.link_to_handle(user)
    text = reminder.print_details(user)
    link.present? && text.present? ? link_to(safe_format(text).html_safe, link) : nil
  rescue => e
    Rails.logger.error "Error #{e.message}: #{e.inspect}"
    return nil
  end

  def get_valid_reminders(reminders, user)
    reminders.present? ? reminders.select { |x| reminder_event_link(x, user).present? } : []
  end

  def count_valid_reminder(reminders, user)
    get_valid_reminders(reminders, user).size
  end
end
