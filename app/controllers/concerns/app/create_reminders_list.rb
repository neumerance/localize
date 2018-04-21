module App
  module CreateRemindersList
    def create_reminders_list
      return if !@user || (params[:format] == 'xml') || request.xhr?

      session[:show_reminders] = false # default value. If we have anything, we'll change it

      controller = params[:controller]
      action = params[:action]

      if (controller == 'client') || (controller == 'translator') || (controller == 'partner') || (controller == 'supporter') ||
         (controller == 'finance') || ((controller == 'users') && (action == 'my_profile')) ||
         ((controller == 'projects') && ((action == 'index') || (action == 'summary'))) ||
         (controller == 'text_resources') || (controller == 'resource_strings') || (controller == 'managed_works') ||
         (controller == 'resource_chats')
        condition = nil
      elsif (controller == 'projects') && (action == 'show')
        condition = "((reminders.owner_type='Project') AND (reminders.owner_id=#{@project.id})) OR
        ((reminders.owner_type='Revision') AND EXISTS (
          SELECT * FROM revisions WHERE (revisions.id=reminders.owner_id) AND (revisions.project_id=#{@project.id}))) OR
        ((owner_type='Chat') AND EXISTS (
          SELECT * FROM chats, revisions WHERE (chats.id=reminders.owner_id) AND (chats.revision_id=revisions.id) AND (revisions.project_id=#{@project.id}))) OR
        ((owner_type='Bid') AND EXISTS (
          SELECT * FROM bids, chats, revisions WHERE (bids.id=reminders.owner_id) AND (bids.chat_id=chats.id) AND (chats.revision_id=revisions.id) AND (revisions.project_id=#{@project.id}))) OR
        ((owner_type='RevisionLanguage') AND EXISTS (
          SELECT * FROM revision_languages, revisions WHERE (revision_languages.id=reminders.owner_id) AND (revision_languages.revision_id=revisions.id) AND (revisions.project_id=#{@project.id}))) OR
        (owner_type='Invoice')"
      elsif (controller == 'revisions') && (action == 'show')
        condition = "((reminders.owner_type='Revision') AND (reminders.owner_id=#{@revision.id})) OR
        ((owner_type='Chat') AND EXISTS (
          SELECT * FROM chats WHERE (chats.id=reminders.owner_id) AND (chats.revision_id=#{@revision.id}))) OR
        ((owner_type='Bid') AND EXISTS (
          SELECT * FROM bids, chats WHERE (bids.id=reminders.owner_id) AND (bids.chat_id=chats.id) AND (chats.revision_id=#{@revision.id}))) OR
        ((owner_type='RevisionLanguage') AND EXISTS (
          SELECT * FROM revision_languages WHERE (revision_languages.id=reminders.owner_id) AND (revision_languages.revision_id=#{@revision.id}))) OR
        (owner_type='Invoice')"
      elsif (controller == 'chats') && (action == 'show')
        condition = "((reminders.owner_type='Chat') AND (reminders.owner_id=#{@chat.id})) OR
        ((owner_type='Bid') AND EXISTS (
          SELECT * FROM bids WHERE (bids.id=reminders.owner_id) AND (bids.chat_id=#{@chat.id}))) OR
        (owner_type='Invoice')"
      elsif (controller == 'arbitrations') && (action == 'show')
        condition = "(owner_type='Arbitration') AND (owner_id=#{@arbitration.id})"
      elsif (controller == 'support') && (action == 'index')
        condition = "(owner_type='SupportTicket')"
      elsif %w(wpml/websites wpml/translation_jobs wpml/payments).include? controller
        # TODO: do we need specific condition here?
        condition = nil
      else
        return
      end

      @reminders = @user.reminders.includes(:owner).where(condition).order('reminders.id DESC')
      if @reminders&.any?
        session[:show_reminders] = true
        session[:reminders_conditions] = condition
      else
        session[:reminders_conditions] = nil
      end

      @onload ||= ''
      @onload += if session[:hide_reminders]
                   'hide_reminders(); '
                 else
                   'show_reminders(); '
                 end

      true
    end
  end
end
