module App
  module DoVerifyOwnership
    # TODO: candidate for moving to auth - pundit or something similar. spetrunin 11/21/2016
    def do_verify_ownership(ids)
      if @user.nil?
        set_err('Not logged in', NOT_LOGGED_IN_ERROR)
        return false
      end

      if ids[:project_id].nil?
        set_err('No project specified', PROJECT_NOT_SPECIFIED)
        return false
      end

      begin
        @project = Project.find(ids[:project_id])
      rescue
        set_err('Project not found', PROJECT_NOT_FOUND)
        return false
      end

      unless ids[:support_file_id].nil?
        return false unless set_support_file(ids[:support_file_id])
      end

      unless ids[:revision_id].nil?
        # get the revision and check that it's part of the project
        begin
          @revision = Revision.find(ids[:revision_id])
          if @revision.project_id != @project.id
            set_err('Revision not part of project')
            return false
          end
        rescue
          set_err('Revision not found')
          return false
        end

        unless ids[:version_id].nil?
          # get the version and check that it's part of the message
          begin
            @version = ::Version.find(ids[:version_id])
            if @version.owner_id != @revision.id
              set_err('Version is not part of this revision')
              return false
            end
          rescue
            set_err('Version not found')
            return false
          end
        end

        unless ids[:chat_id].nil?
          # get the chat and check that it's part of the revision
          begin
            @chat = Chat.find(ids[:chat_id])
            if @chat.revision_id != @revision.id
              set_err('Chat is not part of project revision')
              return false
            end
          rescue
            set_err('Chat not found')
            return false
          end

          if !ids[:bid_id].nil?
            # get the bid and check that it's part of the chat
            begin
              @bid = Bid.find(ids[:bid_id])
              if @bid.chat_id != @chat.id
                set_err('Bid is not part of project revision')
                return false
              end
            rescue
              set_err('Bid not found')
              return false
            end

            # bid and message cannot be requested together
          elsif !ids[:message_id].nil?
            # get the message and check that it's part of the chat
            begin
              @message = Message.find(ids[:message_id])
              if @message.chat_id != @chat.id
                set_err('Message is not part of project revision')
                return false
              end
            rescue
              set_err('Message not found')
              return false
            end

            unless ids[:attachment_id].nil?
              # get the attachment and check that it's part of the message
              begin
                @attachment = ZippedFile.find(ids[:attachment_id])
                if @attachment.owner_id != @message.id
                  set_err('Attachment is not part of this message')
                  return false
                end
              rescue
                set_err('Attachment not found')
                return false
              end
            end
          end
        end
      end

      controller = params[:controller]
      action = params[:action]

      code = "Access forbidden - not your project (or you don't have permission for that)"
      access_ok = false

      # if it's the user's project, he can access anything
      if [@user, @user.master_account].include?(@project.client) || @user.has_admin_privileges?
        access_ok = true
        # if it's a specific chat that belongs to this user, he can access
      elsif ((controller == 'chats') || (controller == 'messages') || (controller == 'attachments') || (controller == 'bids') || (controller == 'arbitrations')) && !@chat.nil?
        # when checking for the reviewer, this is what we do:
        # 1) Create a list of all managed_works for that client that are for revision_languages in the current project's revision
        # 2) Check if the chat's revision_languages include the owners of these managed_works
        # supporter has no method managed_works

        managed_works_present =
          if @user.type == 'Supporter'
            nil
          else
            @user.managed_works.where(
              '(managed_works.owner_type=?) AND (managed_works.owner_id IN (?)) AND (managed_works.active=?)',
              'RevisionLanguage',
              @revision.revision_languages.collect(&:id),
              MANAGED_WORK_ACTIVE
            ).any?
          end

        @is_reviewer = (@user[:type] == 'Translator') && managed_works_present

        if (@chat.translator_id == @user.id) || @is_reviewer || (@user.has_client_privileges? && @user.can_view?(@project))
          access_ok = true
        end
      elsif (controller == 'revisions') && (action == 'show') &&
            ((@revision.released == 1) ||
             @revision.revision_languages.
              joins(:managed_work).
              where('(managed_works.active=?) AND (managed_works.translator_id IS NULL)', MANAGED_WORK_ACTIVE))

        @is_reviewer = @user[:type] == 'Translator' && managed_revision_languages.any?

        access_ok = true
      elsif ((controller == 'chats') && ((action == 'create') || (action == 'new'))) && (@revision.open_to_bids == 1)
        access_ok = true
        # if the revision is open to bids, any bidder can access it
      elsif ((controller == 'revisions') || (controller == 'versions') || (controller == 'chats')) && !@revision.nil?
        # see if the translator has a chat in this revision
        access_ok = true if @revision.translator_can_access?(@user)

        @is_reviewer = @user[:type] == 'Translator' && managed_revision_languages.any?

        access_ok = true if @is_reviewer

        if !access_ok && !@is_reviewer
          code = _('You can only download projects where your bid was accepted or you were granted access')
        end
      end

      # check if the translator may do this call
      if access_ok && (@user[:type] == 'Translator') && !@is_reviewer
        if NO_TRANSLATORS_CALLS.key?(controller)
          if NO_TRANSLATORS_CALLS[controller].include?(action)
            access_ok = false
            code = 'This operation is not allowed for translators'
          end
        end
      end

      create_reminders_list if access_ok

      unless access_ok
        set_err(code, ACCESS_DENIED_ERROR)
        return false
      end

      true
    end

    def managed_revision_languages
      revision_langs_ids = @revision.revision_languages.pluck(:id)
      user_managed_works_langs_ids =
        @user.managed_works.where(
          '(managed_works.owner_type=?) AND (managed_works.owner_id IN (?)) AND (managed_works.active=?)',
          'RevisionLanguage',
          revision_langs_ids,
          MANAGED_WORK_ACTIVE
        ).pluck(:owner_id)

      @revision.revision_languages.where(id: user_managed_works_langs_ids)
    end
    private :managed_revision_languages
  end
end
