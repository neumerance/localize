module Reminders
  def delete_all_reminders_for_bid_and_chat(bid, chat)
    # Delete previous bid reminders
    delete_reminder_for_bid(bid, bid.chat.translator)
    delete_reminder_for_bid(bid, bid.chat.revision.project.client)

    # and previous message reminders
    delete_user_reminder_for_message(chat, chat.translator)
    delete_user_reminder_for_message(chat, chat.revision.project.client)

    # last, remove any revision_language reminders
    delete_reminder_for_revision_language(bid.revision_language)
  end

  def delete_reminder_for_bid(bid, to_who)
    reminders = Reminder.where("owner_id= ? AND owner_type='Bid' AND normal_user_id= ?", bid.id, to_who.id)
    for reminder in reminders
      bid.reminders.delete(reminder)
      reminder.destroy
    end
  end

  def delete_reminder_for_revision_language(revision_language)
    reminders = Reminder.where("owner_id= ? AND owner_type='RevisionLanguage'", revision_language.id)
    for reminder in reminders
      revision_language.reminders.delete(reminder)
      reminder.destroy
    end
  end
  private :delete_reminder_for_revision_language

  def create_reminder_for_bid(bid, to_who, event)
    reminder = Reminder.find_by(owner: bid, normal_user: to_who, event: event)

    unless reminder
      reminder = Reminder.new(event: event)
      reminder.normal_user = to_who
      bid.reminders << reminder
      reminder.save!
    end
  end
end
