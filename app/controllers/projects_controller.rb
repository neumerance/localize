class ProjectsController < ApplicationController
  prepend_before_action :setup_user
  before_action :verify_ownership, except: [:searcher, :index, :summary, :create, :lookup_by_private_key, :new, :new_sisulizer, :continue_sisulizer, :create_sisulizer]
  before_action :verify_client, only: [:index, :summary, :new]
  before_action :create_reminders_list, only: [:index, :summary]
  before_action :setup_help
  before_action :setup_website, only: [:create, :show]
  layout :determine_layout

  def index
    if params[:format] == 'xml'
      @projects = @user.projects.joins(:revisions).where('revisions.cms_request_id IS NULL')
    else
      projects_filter = []
      @possible_project_status = ['All', 'Released', 'Not yet released']
      if params[:status] == 'Released'
        projects_filter << '(revisions.released = 1)'
        @current_project_status = params[:status]
      elsif params[:status] == 'Not yet released'
        projects_filter << '(revisions.released = 0)'
        @current_project_status = params[:status]
      else
        @current_project_status = 'All'
      end

      unless params[:name].blank?
        projects_filter << '(projects.name like ?)'
        @current_name = params[:name]
      end
      params[:page] = 1 if params[:status] != params[:prev_status]

      projects_filter << '(revisions.cms_request_id IS NULL)'

      if @user.has_supporter_privileges?
        unless User.system_user_ids.blank?
          projects_filter << "(projects.client_id NOT IN (#{User.system_user_ids.join(',')}))"
        end
        projects_filter = projects_filter.join(' AND ')
        if @current_name
          projects_filter = [projects_filter, "%#{@current_name}%"]
        end
        revisions = Revision.where(projects_filter).joins(:project)
        @pager = ::Paginator.new(revisions.count, PER_PAGE) do |offset, per_page|
          revisions.order('revisions.id DESC').limit(per_page).offset(offset).collect(&:project)
        end
        @header = _('Browse live projects')
      else
        projects_filter = if projects_filter == []
                            nil
                          else
                            projects_filter.join(' AND ')
                          end
        user_revisions = @user.revisions.where(projects_filter).joins(:project, :revision_languages)
        projects_count = @user.projects.where(projects_filter).joins(:revisions).count

        @pager = ::Paginator.new(projects_count, PER_PAGE) do |offset, per_page|
          user_revisions.limit(per_page).offset(offset).order('revisions.id DESC').distinct(:language_id).map(&:project)
        end
        @header = _('Your projects')
      end
      @projects = @pager.page(params[:page])
      @list_of_pages = []
      for idx in 1..@pager.number_of_pages
        @list_of_pages << idx
      end
      @show_number_of_pages = true # (@pager.number_of_pages > 1)
    end

    respond_to do |format|
      format.html
      format.xml
    end
  end

  def searcher
    name_filter = params[:project_filter]
    name_filter = '' if name_filter.nil?
    @revisions = @user.bidding_projects.
                 where('projects.name LIKE ?', "%#{name_filter}%").
                 joins(:project).
                 order('projects.id DESC').
                 page(params[:page]).
                 per(PER_PAGE_SUMMARY)
    @projects = @revisions.map(&:project).uniq
    @project_message = if @revisions.total_pages > 1
                         _('Page %d of %d of bidding projects') % [@revisions.current_page, @revisions.total_pages] +
                           "&nbsp;&nbsp;&nbsp;<a href=\"#{url_for(controller: :projects, action: :index)}\">" + _('Older bidding projects') + '</a>' \
                                                  "&nbsp;&nbsp;&nbsp;<a href=\"#{url_for(controller: :projects, action: :summary)}\">" + _('Summary of all bidding projects') + '</a>'
                       else
                         _('Showing all your bidding website translation projects')
                       end

    respond_to do |format|
      format.js
    end
  end

  def summary
    if @user.has_supporter_privileges?
      @header = _('Summary of all live projects')
      @projects =
        Revision.where('(projects.client_id NOT IN (?)) AND (revisions.cms_request_id IS NULL)', User.system_user_ids).
        joins(:project).
        order('revisions.id DESC').
        collect(&:project)
    else
      @header = _('Your projects - summary')
      @projects = @user.revisions.order('revisions.id DESC').joins(:project).collect(&:project)
    end
  end

  def create
    unless @user.has_client_privileges?
      set_err('Only clients can create projects', ONLY_CLIENT_CAN_CREATE_PROJECT_ERROR)
      return false
    end

    unless @user.can_create_projects?(@website)
      set_err "You can't do that"
      return
    end

    ok = false
    err_msg = 'Project not created'
    err_code = PROJECT_CANNOT_BE_SAVED_ERROR

    if !params[:project].blank?
      name = params[:project][:name]
      kind = params[:project][:kind] || MANUAL_PROJECT
      source = params[:project][:source]
    else
      name = params[:name]
      kind = params[:kind] || TA_PROJECT
      source = params[:source]
    end

    private_key = params[:private_key] || Time.now.to_i
    @project = Project.new(name: name,
                           kind: kind,
                           source: source,
                           creation_time: Time.now,
                           private_key: private_key)
    if @user.alias?
      @project.client = @user.master_account
      @project.alias = @user
    else
      @project.client = @user
      @project.alias = nil
    end
    ok = @project.save
    @project.track_hierarchy(@user_session, false) if ok

    respond_to do |format|
      format.html do
        if ok
          revision = Revision.new(name: 'Initial',
                                  released: 0,
                                  max_bid: 0,
                                  auto_accept_amount: 0,
                                  kind: @project.kind,
                                  creation_time: Time.now,
                                  max_bid_currency: DEFAULT_CURRENCY_ID)
          revision.project = @project
          revision.save!
          redirect_to controller: :revisions, action: :show, id: revision.id, project_id: @project.id
        else
          @header = _('Create a new project')
          err_msg = 'Project already exists'
          err_code = PROJECT_ALREADY_EXISTS_ERROR
          render action: :new
        end
      end
      format.xml do
        if ok
          @result = { 'message' => 'Project created', 'id' => @project.id }
        else
          set_err(err_msg, err_code)
        end
      end
    end
  end

  def new
    unless @user.can_create_projects?
      set_err("You can't do that.")
      return
    end

    @header = _('Create a new project')
    @project = Project.new(kind: MANUAL_PROJECT)
  end

  def can_create_new_revisions
    @header = "#{_('Project')}: #{@project.name}"
    can_create_stat = @project.can_create_new_revisions
    @result = { 'can_create_new_revisions' => can_create_stat[0] }
    if !can_create_stat[0] && can_create_stat[1]
      @result['revision_id'] = can_create_stat[1].id
    end
    respond_to do |format|
      format.html
      format.xml
    end
  end

  def show
    unless @user.can_view?(@project)
      set_err "You can't do this"
      return
    end

    respond_to do |format|
      format.html do
        redirect_to project_revision_path(@project, @project.revisions.first)
      end
      format.xml
    end
  end

  def lookup_by_private_key
    private_key = params[:private_key].to_i
    @project = Project.where('projects.private_key=?', private_key).first
    if @project
      id = @user.master_account.try(:id) || @user.id
      if @project.client_id != id
        set_err('Not your project', ACCESS_DENIED_ERROR)
        return
      end
    else
      set_err('Project not found', NOT_FOUND_ERROR)
      return
    end
    respond_to do |format|
      format.html
      format.xml
    end
  end

  def delete
    if @project.can_delete_with_siblings
      @project.delete_siblings
      @project.destroy
      @status = 'Project deleted'
    else
      @status = 'Project cannot be deleted now'
    end

    @result = { 'message' => @status }

    respond_to do |format|
      format.html
      format.xml
    end
  end

  private

  def verify_ownership
    do_verify_ownership(project_id: params[:id])
  end

  def verify_client
    if @user[:type] == 'Translator'
      redirect_to controller: :translator
      false
    end
  end

  def setup_website
    # This is needed to validate if an alias can create projects on a website.
    # The website is retrieved and used to check the permissions on the action itself.
    private_key = nil
    website = nil
    alias_can_create = false
    if params[:private_key]
      private_key = params[:private_key]
      cms_term = CmsTerm.where('kind = ? and txt like ?', 'private_key', "%#{private_key}").first
      @website = cms_term.website if cms_term
    else
      private_key = Time.now.to_i
    end
  end

end
