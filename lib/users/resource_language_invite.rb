module Users
  class ResourceLanguageInvite < InviteToJob
    def find_job
      @job = ResourceLanguage.find_by(id: job_id)
    end

    def send_invite
      resource_chat = job.resource_chats.where('translator_id=?', @auser.id).first

      if resource_chat
        @problem = _('Translator already invited')
      else
        resource_chat = ResourceChat.new(status: RESOURCE_CHAT_NOT_APPLIED, word_count: 0)
        resource_chat.resource_language = job
        resource_chat.translator = @auser
        resource_chat.save

        message = Message.new(body: message, chgtime: Time.now)
        message.user = @user
        message.owner = resource_chat
        message.save!

        message_delivery = MessageDelivery.new
        message_delivery.user = @auser
        message_delivery.message = message
        message_delivery.save

        @auser.create_reminder(EVENT_NEW_RESOURCE_TRANSLATION_MESSAGE, resource_chat)
        if @auser.can_receive_emails?
          ReminderMailer.new_message_for_resource_translation(@auser, resource_chat, message).deliver_now
        end

        @redirect = { controller: :resource_chats, action: :show, id: resource_chat.id, text_resource_id: job.text_resource.id }
      end
    end

    def permissions_ok?
      @user.can_modify?(job.text_resource)
    end
  end
end
