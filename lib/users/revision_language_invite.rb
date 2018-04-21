module Users
  class RevisionLanguageInvite < InviteToJob
    include ChatFunctions

    def find_job
      @job = RevisionLanguage.find_by(id: job_id)
    end

    def send_invite
      chat = job.revision.chats.find_by(translator_id: auser)

      if chat
        @problem = _('Translator already invited')
      else
        chat = Chat.new(translator_has_access: 0)
        chat.revision = job.revision
        chat.translator = @auser
        chat.save

        create_message_in_chat(chat, @user, [@auser], message)

        @redirect = { controller: :chats, action: :show, id: chat.id, revision_id: chat.revision.id, project_id: chat.revision.project.id }
      end
    end

    def permissions_ok?
      @user.can_modify?(job.revision)
    end
  end
end
