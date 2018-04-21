class IssuesController < ApplicationController
  include ::TargetUsers

  prepend_before_action :setup_user
  before_action :locate_issue, except: [:index, :new, :create, :project, :issues_i_created, :issues_for_me]
  before_action :verify_admin, only: [:update, :destroy]
  before_action :setup_help
  layout :determine_layout

  def index
    @total_created_issues = @user.created_issues.count
    @created_issues = @user.created_issues.all.limit(PER_PAGE).order('status ASC')
    @created_issues.to_a.delete_if { |i| i.owner.nil? }

    @total_targeted_issues = @user.targeted_issues.count
    @targeted_issues = @user.targeted_issues.all.limit(PER_PAGE).order('status ASC')
    @targeted_issues.to_a.delete_if { |i| i.owner.nil? }

    @header = _('Your issues summary')
  end

  def issues_i_created
    @header = 'Issues that you created'
    @created_issues = @user.created_issues.order('status ASC').page(params[:page]).per(params[:per_page])
    @created_issues.to_a.delete_if { |i| i.owner.nil? }
  end

  def issues_for_me
    @header = 'Issues created for you'
    @targeted_issues = @user.targeted_issues.order('status ASC').page(params[:page]).per(params[:per_page])
    @targeted_issues.to_a.delete_if { |i| i.owner.nil? }
  end

  def project
    @project_type = params[:project_type]
    @project_id = params[:project_id].to_i

    obj = nil
    ids = []
    owner_type = nil
    if @project_type == 'TextResource'
      begin
        obj = TextResource.find(@project_id)
      rescue
      end

      if obj
        ids = obj.string_translations.collect(&:id)
        owner_type = 'StringTranslation'
      end
    end

    unless obj
      set_err('cannot find this project')
      return
    end

    @issues = Issue.where('(issues.owner_type = ?) AND (issues.owner_id in (?))', owner_type, ids).order('issues.status ASC')

    @back = request.referer

    @header = _('Issues for %s') % obj.name
  end

  def new
    @header = _('Create a new issue')

    # get the users to open for
    idx = 1
    cont = true
    @users = [['-- Choose --', 0]]
    while cont
      if !params["user#{idx}"].blank? && !params["desc#{idx}"].blank?
        begin
          user = User.find(params["user#{idx}"].to_i)
        rescue
          set_err('cannot find user %d' % idx)
          return false
        end
        @users << [user.full_name + " (#{params["desc#{idx}"]})", user.id]
        idx += 1
      else
        cont = false
      end
    end
    if @users.empty?
      flash[:notice] = _('No one to open this issue to')
      redirect_to request.referer
    end

    @kinds = [['-- Choose --', 0]] + ISSUE_KINDS.collect { |kind| [Issue::KIND_TEXT[kind], kind] }

    @issue = Issue.new(owner_type: params[:object_type], owner_id: params[:object_id].to_i)

    @issue.target_id = @users[-1][1] if @users.length <= 2

    session[:issue_users] = @users

    @back = request.referer
  end

  def create
    @issue = Issue.new(params[:issue])
    @issue.initiator = @user
    @issue.status = ISSUE_OPEN
    if !@issue.message.blank? && @issue.save
      message = Message.new(body: @issue.message, chgtime: Time.now)
      message.user = @user
      message.owner = @issue
      if message.valid?
        message.save!

        @issue.target.create_reminder(EVENT_NEW_ISSUE_MESSAGE, @issue)
        if @issue.target.can_receive_emails?
          ReminderMailer.new_issue(@issue.target, @issue, message).deliver_now
        end
        create_attachments_for_message(message, params)
      else
        flash[:notice] = list_errors(message.errors.full_messages)
      end

      redirect_to action: :show, id: @issue.id
    else
      @issue.errors.add(:message, 'cannot be blank') if @issue.message.blank?

      @header = _('Create a new issue')
      @users = session[:issue_users]
      logger.info "---------- loading issue_users:#{@users}"
      @kinds = [['-- Choose --', 0]] + ISSUE_KINDS.collect { |kind| [Issue::KIND_TEXT[kind], kind] }
      @back = params[:back]
      render action: :new
    end
  end

  def show
    project = @issue.project

    @can_modify = @user.can_modify?(project) || @user.is_reviewer_of?(project) || @issue.initiator == @user
    @status_text = Issue::STATUS_TEXT[@issue.status]
    @status_actions = @issue.status == ISSUE_OPEN ? [[_('Close this issue'), ISSUE_CLOSED]] : [[_('Reopen this issue'), ISSUE_OPEN]]
    @header = _('Issue - %s') % @issue.title
    @kinds = ISSUE_KINDS.collect { |kind| [Issue::KIND_TEXT[kind], kind] }
    @subscribe = params[:subscribe]

    @for_who = collect_target_users(@user, [@issue.initiator, @issue.target], @issue.messages)
  end

  def update_status
    status = params[:status].to_i

    @issue.update_attributes!(status: status)
    if @issue.update_attributes(status: status)
      Reminder.by_owner_and_normal_user(@issue, @user).destroy_all
      flash[:notice] = _('Status updated')
    else
      flash[:notice] = _('Status could not be updated')
    end

    # notify the other side of the issue
    collect_target_users(@user, [@issue.initiator, @issue.target], @issue.messages).each do |user|
      if user.can_receive_emails?
        ReminderMailer.issue_status_updated(user, @issue).deliver_now
      end
    end

    redirect_to action: :show
  end

  # Subscribe for issues
  def subscribe
    params[:body] = "#{@user.nickname} has subscribed to this conversation"
    params[:ack] =  'You have subscribed this issue'
    params[:from] = 'subscribe'
    params[:max_idx] = 1
    params[:for_who1] = @issue.owner.get_client_id
    create_message
  end

  def create_message
    if @orig_user
      flash[:notice] = "you can't post a message while logged in as other user"
      redirect_to :back
      return
    end

    warnings = []

    to_who = get_target_users
    if to_who.empty?
      warnings << _('You must select at least one target for this message')
    end

    warnings << _('No message entered') if params[:body].blank?

    if warnings.empty?
      message = Message.new(body: params[:body], chgtime: Time.now)
      message.valid?
      if message.errors.blank?
        message.user = @user
        message.owner = @issue
        message.save!

        Reminder.by_owner_and_normal_user(@issue, @user).destroy_all

        # other_side = (@user == @issue.initiator) ? @issue.target : @issue.initiator
        to_who.each do |user|
          if user.can_receive_emails?
            ReminderMailer.new_message_for_issue(user, @issue, message).deliver_now
          end
          message_delivery = MessageDelivery.new
          message_delivery.user = user
          message_delivery.message = message
          message_delivery.save
          if %w(Client Translator Alias).include?(user[:type])
            user.create_reminder(EVENT_NEW_ISSUE_MESSAGE, @issue)
          end
        end
        create_attachments_for_message(message, params)
      else
        flash[:notice] = list_errors(message.errors.full_messages)
      end

      respond_to do |format|
        format.html { request.referer ? (redirect_to :back) : (render plain: '') }
        format.js
      end
    end

    flash[:ack] = params[:ack] ? params[:ack] : _('Your message was sent!')
    @warning = warnings.collect { |w| "- #{w}." }.join("\n") unless warnings.empty?
  end

  def attachment
    begin
      attachment = Attachment.find(params[:attachment_id])
    rescue
      set_err('Cannot find attachment')
      return
    end
    if attachment.message.owner != @issue
      set_err("attachment doesn't belong to this issue")
      return
    end
    send_file(attachment.full_filename)
  end

  def update
    @issue.update_attributes(params[:issue])
    flash[:notice] = 'Issue data updated'
    redirect_to action: :show
  end

  private

  def locate_issue
    begin
      @issue = Issue.find(params[:id].to_i)
    rescue
      set_err('Cannot locate this issue', 404)
      return false
    end

    alias_can_access = @user.is_alias? && [@issue.initiator, @issue.target].include?(@user.master_account) && @user.can_view?(get_project)

    # if this is the initiator, target or support - give access
    if alias_can_access || (@user == @issue.initiator) || (@user == @issue.target) || @user.has_supporter_privileges?
      return true
    end

    # check if there's a key parameter
    key = params[:key]
    if key
      session[:issue_keys] = {} unless session[:issue_keys]
      session[:issue_keys][@issue.id] = key
    elsif session[:issue_keys]
      key = session[:issue_keys][@issue.id]
    end

    # check access rights
    return true if key == @issue.key

    set_err('Not your issue')
    false
  end

  def verify_admin
    @user.has_supporter_privileges?
  end

  def get_project
    if @issue.owner.is_a? StringTranslation
      @issue.owner.text_resource
    elsif @issue.owner.is_a? RevisionLanguage
      @issue.owner.revision
    else
      @issue.owner
    end
  end

end
