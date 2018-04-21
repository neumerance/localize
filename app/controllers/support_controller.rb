class SupportController < ApplicationController
  prepend_before_action :setup_user
  before_action :verify_supporter, only: [:supporter_index, :supporter_browse, :supporter_find_results,
                                          :assume_responsibility, :drop_responsibility, :close_ticket]
  before_action :verify_ownership, only: [:show, :create_message, :assume_responsibility, :drop_responsibility, :close_ticket, :attachment]
  before_action :create_reminders_list, only: [:index, :tickets_summary]
  before_action :get_object_for_ticket, only: [:new_support_ticket_for_object, :create_support_ticket_for_object, :cancel_support_ticket_for_object]

  layout :determine_layout
  before_action :setup_help

  def index
    @header = _('Your Support')

    if params[:format] != 'xml'
      @support_tickets = @user.support_tickets.includes(:supporter).order('support_tickets.id DESC').limit(PER_PAGE)
      ticket_count = @user.support_tickets.count
      if @support_tickets.length < ticket_count
        @your_tickets_message = _('Recent %d of %d support tickets') % [PER_PAGE, ticket_count] +
                                "&nbsp;&nbsp;&nbsp;<a href=\"#{url_for(action: :tickets_summary)}\">" + _('Summary of all tickets') + '</a>'
        @show_all_tickets = true
      else
        @your_tickets_message = _('Showing all your support tickets')
      end

      @alias_support_tickets = []
      if @user.instance_of? Client
        aliases_ids = @user.aliases.map(&:id)
        @alias_support_tickets = SupportTicket.where(['normal_user_id IN (?)', aliases_ids])
      end
    else
      wid = params[:wid].to_i
      @support_tickets = if wid != 0
                           @user.support_tickets.includes(:supporter, :messages).where(['(object_type IS NULL) OR (object_type != ?) OR (object_id = ?)', 'Website', wid])
                         else
                           @user.support_tickets.includes(:supporter, :messages)
                         end
    end

    respond_to do |format|
      format.html
      format.xml
    end

  end

  def update_supporter_data
    obj = SupportTicket.find(params[:support_ticket][:id])
    logger.debug obj.inspect
    logger.debug params.inspect
    obj.update_attributes(params[:support_ticket])
    flash[:notice] = _('Updated!')
    redirect_to action: :show, id: params[:support_ticket][:id]
  end

  def tickets_summary
    @header = _('Summary of Your Support Tickets')
    @support_tickets = @user.support_tickets.order('id DESC')
  end

  def new
    @back = request.referer.blank? ? { action: :index } : request.referer

    # if the user is not registered yet, first, ask for that
    if @user.anon == 1
      redirect_to(controller: :users, action: :signup, return_to: request.url)
      return
    end

    @support_ticket = SupportTicket.new
    @support_ticket.subject = params[:subject] if params[:subject]
    @support_ticket.support_department_id = params[:dep_id] if params[:dep_id]
    if params[:help_setup]
      department = SupportDepartment.where(name: SETUP_PROJECT_REQUEST).first
      @support_ticket.support_department_id = department.try(:id)
      @hide_support_department = true
      @header = _('Ask us a question')
    else
      @header = _('Create a New Ticket')
    end
  end

  def new_full_service_project
    @header = _('Request a new Full Service Project')
    @support_ticket = SupportTicket.new
    @support_ticket.support_department_id = SupportDepartment.where(name: SETUP_PROJECT_REQUEST).first.id
    @cms = (params[:kind] == 'cms')
  end

  def create
    if @user.is_a? Supporter
      flash[:notice] = "You can't create a support ticket as a supporter. Please switch to a client first."
      return
    end

    @support_ticket = SupportTicket.new(params[:support_ticket])
    @support_ticket.create_time = Time.now
    @support_ticket.status = SUPPORT_TICKET_CREATED
    @support_ticket.normal_user = @user
    @back = { action: :index }
    attachment_problem = false
    ok = false
    if params[:project] && (params[:project] != '0')
      model, id = params[:project].split('-')
      raise unless model && id
      raise unless %w(Website TextResource Revision WebMessage).include? model
      object = model.constantize.find(id)
      raise unless @user.send(model.tableize.pluralize).include?(object)
      @support_ticket.object = object
    end

    SupportTicket.transaction do
      if @support_ticket.save

        # add WP credentials if project is Website
        @support_ticket.object.update(wp_login_url: @support_ticket.wp_login_url, wp_password: @support_ticket.wp_password, wp_username: @support_ticket.wp_username) if @support_ticket.object.is_a?(Website)

        # create the first message in this ticket
        message = Message.new(body: @support_ticket.message, chgtime: Time.now)
        if message.valid?
          message.owner = @support_ticket
          message.user = @user
          message.save!

          attachment_problem = true unless create_attachments_for_message(message)
          ok = true
        else
          ok = false
          attachment_problem = false
          flash[:notice] = list_errors(message.errors.full_messages)
        end
      end
    end

    if ok
      unless @user.has_supporter_privileges?
        recipients = Admin.all.select { |x| (x.send_admin_notifications && !x.on_vacation?) }
        ReminderMailer.notify_support_about_new_ticket(recipients.map(&:email), @support_ticket).deliver_now
      end
      flash[:notice] = if attachment_problem
                         _('Your ticket was created, but attachments failed to upload. Please try a different browser.')
                       else
                         _('Ticket created')
                       end
      redirect_to action: :index
    else
      @header = _('Create a New Ticket')
      @cms = (params[:kind] == 'cms')
      retry_action = params[:retry]
      if retry_action && 'new_full_service_project' == retry_action
        render(action: :new_full_service_project) && return
      end
      @show_wp_credentials = params[:project] && params[:project].match('Website-') && @support_ticket.support_department_id == 1
      render action: :new
    end
  end

  def show
    @header = @support_ticket.subject
    @can_assume_responsibility = @user.has_supporter_privileges? && (@support_ticket.supporter_id != @user.id)
    @can_drop_responsibility = @user.has_supporter_privileges? && (@support_ticket.supporter_id == @user.id)
    @can_close = (@support_ticket.supporter_id == @user.id) && [SUPPORT_TICKET_CREATED, SUPPORT_TICKET_WAITING_REPLY].include?(@support_ticket.status)

    @internal_note_urls = @support_ticket.note.get_urls if @support_ticket.note

    if @support_ticket.subject =~ /#EE(\d+)/
      @user_click = UserClick.find($~[1]) rescue (logger.info('NOT VALID User Click') && false)
    end

    respond_to do |format|
      format.html
      format.xml
    end

  end

  def attachment
    begin
      attachment = Attachment.find(params[:attachment_id])
    rescue
      set_err('Cannot find attachment')
      return
    end
    if attachment.message.owner != @support_ticket
      set_err("attachment doesn't belong to this ticket")
      return
    end
    send_file(attachment.full_filename)
  end

  def create_message
    if @orig_user
      flash[:notice] = "you can't post a message while logged in as other user"
      redirect_to :back
      return
    end

    if params[:body].blank?
      flash[:notice] = _('No message posted')
    else
      message = Message.new(body: params[:body], chgtime: Time.now)
      message.valid?
      if message.errors.blank?
        message.owner = @support_ticket
        message.user = @user

        attachment_problem = false

        Message.transaction do
          message.save!

          attachment_problem = false unless create_attachments_for_message(message)

          leave_open = !params[:leave_open].blank?

          if @user.has_supporter_privileges? && !leave_open
            @support_ticket.update_attributes!(status: SUPPORT_TICKET_ANSWERED)
          elsif @support_ticket.status != SUPPORT_TICKET_CREATED
            @support_ticket.update_attributes!(status: SUPPORT_TICKET_WAITING_REPLY)
          end

          # delete all existing reminders to the user
          delete_user_reminder_for_ticket(@support_ticket.normal_user_id)

          # if it's a supporter reply, create a reminder
          if @user.has_supporter_privileges?
            create_user_reminder_for_ticket(@support_ticket.normal_user_id, EVENT_TICKET_UPDATE)
          else
            if @support_ticket.supporter
              ReminderMailer.notify_support_about_ticket_update(@support_ticket.supporter, @support_ticket).deliver_now
            else
              Admin.all.each do |admin|
                if admin.send_admin_notifications
                  ReminderMailer.notify_support_about_ticket_update(admin, @support_ticket).deliver_now
                end
              end
            end
          end
        end

        flash[:notice] = attachment_problem ? _('Your message was added, but attachments failed to upload. Please try a different browser.') : _('Your message was added')
      else
        flash[:notice] = list_errors(message.errors.full_messages)
      end
    end
    redirect_to action: :show, id: @support_ticket.id, t: Time.now.to_i
  end

  def assume_responsibility
    @support_ticket.supporter = @user
    @support_ticket.save!

    redirect_to action: :show, id: @support_ticket.id
  end

  def drop_responsibility
    @support_ticket.supporter = nil
    @support_ticket.save!

    redirect_to action: :show, id: @support_ticket.id
  end

  # ------------- supporter functions ------------------
  def supporter_index
    @new_support_tickets = SupportTicket.where(['supporter_id IS NULL']).order('id ASC')
    @my_pending_tickets = @user.support_tickets.where(["status IN (#{[SUPPORT_TICKET_CREATED, SUPPORT_TICKET_WAITING_REPLY].join(',')})"]).order('id ASC')
    @header = 'ICL tickets'
    if @my_pending_tickets.count + @new_support_tickets.count > 0
      @header += ' - '
    end
    if @my_pending_tickets.count > 0
      @header += "#{@my_pending_tickets.count} yours"
    end
    if @my_pending_tickets.count > 0 && @new_support_tickets.count > 0
      @header += ', '
    end
    if @new_support_tickets.count > 0
      @header += "#{@new_support_tickets.count} new"
    end
  end

  def supporter_browse
    @filter_by_my = !params[:my].blank?
    @header = 'Browse assigned tickets'

    @user_conditions = {}
    @ticket_conditions = {}
    if !params[:set_args].blank?
      @user_conditions['fname'] = params[:fname] unless params[:fname].blank?
      @user_conditions['lname'] = params[:lname] unless params[:lname].blank?
      @user_conditions['email'] = params[:email] unless params[:email].blank?
      @user_conditions['nickname'] = params[:nickname] unless params[:nickname].blank?

      @ticket_conditions['subject'] = params[:subject] unless params[:subject].blank?
      @ticket_conditions['supporter_id'] = @user.id if (params[:my].to_i == 1) || params[:my].blank?
      if !params[:support_department_id].blank? && (params[:support_department_id].to_i != 0)
        @ticket_conditions['support_department_id'] = params[:support_department_id].to_i
      end

      session[:user_conditions] = @user_conditions
      session[:ticket_conditions] = @ticket_conditions
    elsif session[:user_condition] && session[:ticket_conditions]
      @user_conditions = session[:user_conditions]
      @ticket_conditions = session[:ticket_conditions]
    end

    @open_only = params[:open_only] unless params[:open_only].nil?

    unless @user_conditions.keys.empty?
      cond = mount_like_query(@user_conditions)
      ausers = User.where(cond)
      @ticket_conditions['normal_user_id'] = ausers.collect(&:id)
    end

    conds = mount_like_query(@ticket_conditions)

    if @open_only
      if conds.nil? || conds.empty?
        conds = "status not in (#{SUPPORT_TICKET_SOLVED},#{SUPPORT_TICKET_CLOSED})"
      else
        conds += "AND status not in (#{SUPPORT_TICKET_SOLVED},#{SUPPORT_TICKET_CLOSED})"
      end
    end

    @pager = ::Paginator.new(SupportTicket.where(conds).count, PER_PAGE) do |offset, per_page|
      SupportTicket.where(conds).order('id ASC').offset(offset).limit(per_page)
    end
    @support_tickets_page = @pager.page(params[:page])
    @list_of_pages = (1..@pager.number_of_pages).collect { |idx| idx }
    @show_number_of_pages = (@pager.number_of_pages > 1)

  end

  def close_ticket
    if !(@support_ticket.supporter_id == @user.id) && [SUPPORT_TICKET_CREATED, SUPPORT_TICKET_WAITING_REPLY].include?(@support_ticket.status)
      set_err('cannot close this ticket')
      return
    end
    if params[:close_status].nil?
      set_err('can\'t close the ticket for this motive')
      return
    end

    @support_ticket.update_attributes!(status: params[:close_status])

    delete_user_reminder_for_ticket(@support_ticket.normal_user_id)
    # create_user_reminder_for_ticket(@support_ticket.normal_user_id, EVENT_TICKET_CLOSED)

    redirect_to action: :show, id: @support_ticket.id
  end

  def new_support_ticket_for_object; end

  def create_support_ticket_for_object
    subject = params[:subject]
    message = params[:message]

    warning = nil
    ok = false

    if @obj.support_ticket
      warning = 'A support ticket already exists for this item'
    elsif subject.blank? || message.blank?
      warning = 'You must enter both a subject and a message'
    else
      support_department = if @user.has_supporter_privileges?
                             SupportDepartment.where(name: SUPPORTER_QUESTION).first
                           else
                             SupportDepartment.find(1) # general question
                           end
      @support_ticket = SupportTicket.new(support_department_id: support_department.id, subject: subject)
      @support_ticket.message = message
      @support_ticket.create_time = Time.now
      if @user.has_supporter_privileges?
        @support_ticket.supporter = @user
        @support_ticket.normal_user = @obj_user
        @support_ticket.status = SUPPORT_TICKET_INITIATED_BY_SUPPORTER
      else
        @support_ticket.normal_user = @user
        @support_ticket.status = SUPPORT_TICKET_CREATED
      end
      @support_ticket.object = @obj
      if @support_ticket.save!
        # create the first message in this ticket
        message = Message.new(body: message, chgtime: Time.now)
        message.owner = @support_ticket
        message.user = @user
        message.save!
        ok = true
        @obj.reload

        if @user.has_supporter_privileges?
          # add reminder to user
          reminder = Reminder.new(event: EVENT_TICKET_FROM_SUPPORTER, normal_user_id: @obj_user.id)
          reminder.owner = @support_ticket
          reminder.save!

          # send email to user
          ReminderMailer.new_ticket_by_supporter(@support_ticket).deliver_now
        else
          recipients = Admin.all.select(&:send_admin_notifications)
          ReminderMailer.notify_support_about_new_ticket(recipients.map(&:email), @support_ticket).deliver_now
        end

      else
        warning = 'Support ticket cannot be saved'
      end
    end
    @warning = warning
  end

  def cancel_support_ticket_for_object; end

  def new_support_ticket_for_user
    begin
      @auser = User.find(params[:id].to_i)
    rescue
      set_err("User doesn't exist")
      return
    end
    @header = "Open a support ticket for #{@auser.full_name}"
  end

  def create_support_ticket_for_user
    begin
      @auser = User.find(params[:id].to_i)
    rescue
      set_err("User doesn't exist")
      return
    end

    @subject = params[:subject]
    @message = params[:message]

    warning = nil
    ok = false

    if @subject.blank? || @message.blank?
      warning = 'You must enter both a subject and a message'
    else
      support_department = SupportDepartment.where(name: SUPPORTER_QUESTION).first

      @support_ticket = SupportTicket.new(support_department_id: support_department.id, subject: @subject)
      @support_ticket.message = @message
      @support_ticket.create_time = Time.now

      @support_ticket.supporter = @user
      @support_ticket.normal_user = @auser
      @support_ticket.status = SUPPORT_TICKET_INITIATED_BY_SUPPORTER

      attachment_problem = false

      if @support_ticket.save!
        # create the first message in this ticket
        message = Message.new(body: @message, chgtime: Time.now)
        message.owner = @support_ticket
        message.user = @user
        message.save!
        ok = true

        attachment_problem = true unless create_attachments_for_message(message)

        # add reminder to user
        reminder = Reminder.new(event: EVENT_TICKET_FROM_SUPPORTER, normal_user_id: @auser.id)
        reminder.owner = @support_ticket
        reminder.save!

        # send email to user
        if @support_ticket.normal_user.can_receive_emails?
          ReminderMailer.new_ticket_by_supporter(@support_ticket).deliver_now
        end

      else
        warning = 'Support ticket cannot be saved'
      end
    end

    if warning
      flash[:notice] = warning
      @header = "Open a support ticket for #{@auser.full_name}"
      render(action: :new_support_ticket_for_user, id: @auser.id)
      return
    elsif attachment_problem
      flash[:notice] = _('Your ticket was created, but attachments failed to upload. Please try a different browser.')
    else
      flash[:notice] = _('Ticket created')
    end
    redirect_to(controller: :users, action: :show, id: @auser.id)
  end

  private

  def mount_like_query(hashmap)
    return nil if hashmap.empty?
    cond_string = ''
    hashmap.each_key do |k|
      if cond_string.empty?
        cond_string = "#{k} like ?"
      else
        cond_string += "AND #{k} like ?"
      end
    end
    [cond_string] + hashmap.values.map { |x| "%#{x}%" }
  end

  def verify_ownership
    begin
      @support_ticket = SupportTicket.find(params[:id].to_i)
    rescue
      set_err(_('Support ticket not found'))
      return false
    end

    if @support_ticket.normal_user.nil?
      set_err(_('Not your ticket'))
      return false
    end

    if (@support_ticket.normal_user_id != @user.id && !@support_ticket.normal_user.alias_of?(@user)) && !@user.has_supporter_privileges?
      set_err(_('Not your ticket'))
      return false
    end

  end

  def verify_supporter
    unless @user.has_supporter_privileges?
      set_err('You cannot do this')
      false
    end
  end

  # ------------- reminders management ---------------
  def delete_user_reminder_for_ticket(to_who_id)
    Reminder.where("owner_id= ? AND owner_type='SupportTicket' AND normal_user_id= ?", @support_ticket.id, to_who_id).delete_all
  end

  def create_user_reminder_for_ticket(to_who_id, event)
    reminder = @support_ticket.reminders.where(['normal_user_id= ? AND event= ?', to_who_id, event]).first
    unless reminder
      reminder = Reminder.new(event: event, normal_user_id: to_who_id)
      reminder.owner = @support_ticket
      reminder.save!

      if @user.has_supporter_privileges? && @support_ticket.normal_user.can_receive_emails?
        if event == EVENT_TICKET_UPDATE
          ReminderMailer.ticket_replied(@support_ticket).deliver_now
        elsif event == EVENT_TICKET_CLOSED
          ReminderMailer.ticket_closed(@support_ticket).deliver_now
        end
      end
    end
  end

  def create_attachments_for_message(message)
    attachment_id = 1
    cont = true
    while cont
      attached_data = params["file#{attachment_id}"]
      if !attached_data.blank? && !attached_data[:uploaded_data].blank?
        begin
          attachment = Attachment.new(attached_data)
        rescue
          return false
        end
        attachment.message = message
        attachment.save
        attachment_id += 1
      else
        cont = false
      end
    end
    true
  end

  def get_object_for_ticket
    obj_type = params[:obj_type]
    obj_class = if (obj_type == 'TranslatorLanguage') || (obj_type == 'TranslatorLanguageFrom') || (obj_type == 'TranslatorLanguageTo')
                  TranslatorLanguage
                elsif obj_type == 'IdentityVerification'
                  IdentityVerification
                elsif obj_type == 'Chat'
                  Chat
                elsif obj_type == 'Revision'
                  Revision
                elsif obj_type == 'TextResource'
                  TextResource
                elsif obj_type == 'ResourceChat'
                  ResourceChat
                elsif obj_type == 'ManagedWork'
                  ManagedWork
                end

    @obj = nil
    if obj_class
      begin
        @obj = obj_class.find(params[:id].to_i)
      rescue
      end
    end

    if @obj
      if (obj_type == 'TranslatorLanguage') || (obj_type == 'TranslatorLanguageFrom') || (obj_type == 'TranslatorLanguageTo')
        @obj_user = @obj.translator
      elsif obj_type == 'IdentityVerification'
        @obj_user = @obj.normal_user
      elsif obj_type == 'Chat'
        if @user != @obj.translator
          set_err('You cannot create this ticket')
          return false
        end
        @obj_user = @user
      elsif obj_type == 'Revision'
        if @user != @obj.project.client && (@user.instance_of?(Alias) && !@user.can_modify?(@project))
          set_err('You cannot create this ticket')
          return false
        end
        @obj_user = @user
      elsif obj_type == 'TextResource'
        if @user != @obj.client
          set_err('You cannot create this ticket')
          return false
        end
        @obj_user = @user
      elsif obj_type == 'ResourceChat'
        if @user != @obj.translator
          set_err('You cannot create this ticket')
          return false
        end
        @obj_user = @user
      elsif obj_type == 'ManagedWork'
        if @user != @obj.translator
          set_err('You cannot create this ticket')
          return false
        end
        @obj_user = @user
      end
    end

    @div_name = params[:div_name]

    if !@obj || !@div_name || !@obj_user
      logger.info '------ Cannot handle the support object - refreshing and aborting'
    end
  end

end
