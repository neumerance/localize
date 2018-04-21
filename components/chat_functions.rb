module ChatFunctions
  def create_message_in_chat(chat, from, to_whos, body, params_to_use = nil)
    message = Message.new(body: body, chgtime: Time.now)
    message.user = from
    message.owner = chat
    if message.valid?
      message.save!

      create_attachments_for_message(message, params_to_use) if params_to_use

      # delete previous message reminders for this chat to the current user
      delete_user_reminder_for_message(chat, from)

      to_whos.each { |to_who| create_user_reminder_for_message(chat, to_who, from, message) }

      chat.count_track # indicate that something's changed in this chat
    end
    message
  end

  def create_attachments_for_message(message, params_to_use)
    attachment_id = 1
    cont = true
    attached = false
    while cont
      attached_data = params_to_use["file#{attachment_id}"]
      if !attached_data.blank? && !attached_data[:uploaded_data].blank?
        attachment = Attachment.new(attached_data)
        attachment.message = message
        attachment.save!
        attachment_id += 1
        attached = true
      else
        cont = false
      end
    end
    message.reload if attached
  end

  def delete_user_reminder_for_message(chat, to_who)
    Reminder.where("owner_id= ? AND owner_type='Chat' AND normal_user_id= ?", chat.id, to_who.id).destroy_all
  end

  # ----- message reminders ------
  def create_user_reminder_for_message(chat, to_who, from, message)
    if to_who.can_receive_emails?
      ReminderMailer.new_message(to_who, from, chat, message).deliver_now

      message_delivery = MessageDelivery.new
      message_delivery.user = to_who
      message_delivery.message = message
      message_delivery.save
    end

    if %w(Alias Client Translator).include?(to_who[:type])
      event = EVENT_NEW_MESSAGE
      reminder = Reminder.where("owner_id= ? AND owner_type='Chat' AND normal_user_id= ? AND event= ?", chat.id, to_who.id, event).first
      unless reminder
        website_id = chat.revision.cms_request ? website_id = chat.revision.cms_request.website_id : nil
        reminder = Reminder.new(event: event, website_id: website_id)
        reminder.normal_user = to_who
        chat.reminders << reminder
        reminder.save!
      end
    end
  end

end
