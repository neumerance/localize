#   TA:
#     When ta start it makes a call to details to obtain all projects
class TranslatorController < ApplicationController

  prepend_before_action :setup_user
  before_action :verify_ownership
  before_action :create_reminders_list
  before_action :setup_help
  layout :determine_layout

  def index
    @header = "#{@user.full_name}'s Home"
    only_ta_projects = params[:format] == 'xml'

    if only_ta_projects
      @chats = @user.get_ta_projects
    else
      @chats = @user.chats
      @work_revisions = @user.work_revisions("LIMIT #{PER_PAGE}", only_ta_projects)
      @bid_revisions = @user.bid_revisions("LIMIT #{PER_PAGE}", only_ta_projects)
      @completed_revisions = @user.completed_revisions(extra_sql: "LIMIT #{PER_PAGE_SUMMARY}", only_ta_projects: only_ta_projects, per_page: 5)

      @revision_reviews = ManagedWork.where('owner_type=? AND active=? AND translator_id=?', 'RevisionLanguage', 1, @user.id).limit(PER_PAGE)
      @have_more_revision_reviews = ManagedWork.where('owner_type=? AND active=? AND translator_id=?', 'RevisionLanguage', 1, @user.id).length > @revision_reviews.length

      @website_translation_contracts = @user.website_translation_contracts.all.limit(PER_PAGE)
      @have_more_website_translation_contracts = @user.website_translation_contracts.count > PER_PAGE

      # make sure that this user is not holding up any web messages
      @user.release_active_web_messages

      @arbitrations = @user.open_arbitrations("LIMIT #{PER_PAGE}")

      @messages = @user.open_web_messages('', 20)
      @review_messages = @user.web_messages_for_review('', 20)

      @show_getting_started = !@embedded && @work_revisions.empty? && !@messages.empty?

      @show_bidding_projects_header = !@work_revisions.empty? || !@bid_revisions.empty? || !@completed_revisions.empty?
      @show_recurring_translation_header = !@website_translation_contracts.empty?

      @resource_chats = @user.resource_chats.where('status=?', RESOURCE_CHAT_ACCEPTED).order('word_count DESC').limit(PER_PAGE)

      @resource_chats_to_deliver = @user.resource_chats.where('(status=?) AND (translation_status=?)', RESOURCE_CHAT_ACCEPTED, RESOURCE_CHAT_TRANSLATOR_NEEDS_TO_REVIEW).order('id ASC')

      if (@resource_chats.length < PER_PAGE) && (@user.resource_chats.count > @resource_chats.length)
        @resource_chats += @user.resource_chats.where.not(status: RESOURCE_CHAT_ACCEPTED).order('word_count DESC').limit(PER_PAGE - @resource_chats.length)
      end

      @have_more_resource_chats = @user.resource_chats.count > PER_PAGE

      @software_reviews = ManagedWork.where('owner_type=? AND active=? AND translator_id=?', 'ResourceLanguage', 1, @user.id).limit(PER_PAGE)
      @have_more_software_reviews = ManagedWork.where('owner_type=? AND active=? AND translator_id=?', 'ResourceLanguage', 1, @user.id).length > @software_reviews.length

      @bidding_reviews = ManagedWork.where('owner_type=? AND active=? AND translator_id=?', 'RevisionLanguage', 1, @user.id).limit(PER_PAGE)
      @have_more_bidding_reviews = ManagedWork.where('owner_type=? AND active=? AND translator_id=?', 'RevisionLanguage', 1, @user.id).length > @software_reviews.length

      @open_issues = @user.targeted_issues.where('status=?', ISSUE_OPEN).order('ID ASC')
      @pending_managed_works = @user.pending_managed_works

      @recurring_managed_works = @user.managed_works.where('(active=?) AND (managed_works.owner_type=?)', MANAGED_WORK_ACTIVE, 'WebsiteTranslationOffer').collect(&:owner)

      @mini_index = [['Projects you are translating', 'project_you_are_translating', !@work_revisions.empty?],
                     ['Projects you bid on', 'projects_you_bid_on', !@bid_revisions.empty?],
                     ['Projects you completed', 'projects_you_completed', !@completed_revisions.empty?],
                     ['Your recurring translation offers', 'your_recurring_website_translation_offers', !@website_translation_contracts.empty?],
                     ['Your recurring review assignments', 'recurring_review_assignments', !@recurring_managed_works.empty?],
                     ['Software localization projects you need to deliver', 'resource_chats_to_deliver', !@resource_chats_to_deliver.empty?],
                     ['Software localization projects you already applied to', 'resource_chats', !@resource_chats.empty?],
                     ['Your arbitrations', 'your_arbitrations', !@arbitrations.empty?]]

      @pending_accepted_private_translations = @user.private_translators.where('status=?', PRIVATE_TRANSLATOR_PENDING)
    end

    respond_to do |format|
      format.html
      format.xml
    end
  end

  def open_work
    @messages = @user.open_web_messages('', 20)
    @review_messages = @user.web_messages_for_review('', 20)

    @revisions_open_to_bids = @user.open_revisions_filtered(true, false, '', "LIMIT #{PER_PAGE}")
    @open_website_translation_offers = @user.open_website_translation_offers('', PER_PAGE)
    @show_all_offers = @open_website_translation_offers.length == PER_PAGE

    @open_website_translation_work = open_website_translation_work_filtered(PER_PAGE)

    @open_text_resource_projects = @user.open_text_resource_projects

    @open_managed_works = @user.open_managed_works

    @mini_index = [['Projects waiting for you', 'open_website_translation_work', !@open_website_translation_work.empty?],
                   ['Projects you can bid on', 'website_translation_projects', !@revisions_open_to_bids.empty?],
                   ['Recurring translation offers you can apply to', 'available_recurring_website_translation_offers', !@open_website_translation_offers.empty?],
                   ['Software localization projects you can apply to', 'open_text_resource_projects', !@open_text_resource_projects.empty?],
                   ['Open review jobs that you can do', 'open_managed_works', !@open_managed_works.empty?]]
  end

  def website_translation_offers
    @header = 'Available recurring translations'
    @website_translation_offers = @user.open_website_translation_offers('', nil)
  end

  def website_translation_contracts
    @header = 'Recurring translation projects'
    @website_translation_contracts = @user.website_translation_contracts
  end

  def website_translation_work
    @header = 'Available recurring translations'
    @open_website_translation_work = open_website_translation_work_filtered(nil)
  end

  def resource_chats
    @software_reviews = ManagedWork.where('owner_type=? AND active=? AND translator_id=?', 'ResourceLanguage', 1, @user.id).page(params[:page]).per(params[:per_page])
  end

  def resource_application
    @resource_chats = @user.resource_chats.where('status=?', RESOURCE_CHAT_ACCEPTED).order('word_count DESC').page(params[:page]).per(params[:per_page])
  end

  def revision_reviews
    params[:page] ||= 1
    @pager = ::Paginator.new(ManagedWork.where('owner_type=? AND active=? AND translator_id=?', 'RevisionLanguage', 1, @user.id).count, PER_PAGE) do |offset, per_page|
      ManagedWork.where('owner_type=? AND active=? AND translator_id=?', 'RevisionLanguage', 1, @user.id).limit(per_page).offset(offset).order('id DESC')
    end
    @revision_reviews = @pager.page(params[:page])
    @list_of_pages = (1..@pager.number_of_pages).to_a
    @show_number_of_pages = (@pager.number_of_pages > 1)
  end

  def projects_in_progress
    @header = 'Projects in progress'
    @revisions = @user.work_revisions('', false, page: params[:page], per_page: params[:per_page])
    render action: :revision_list
  end

  def active_bids
    @header = 'Projects you bid on'
    @revisions = @user.bid_revisions('', false, page: params[:page], per_page: params[:per_page])
    render action: :revision_list
  end

  def completed_projects
    @header = 'Completed projects'
    @revisions = @user.completed_revisions(page: params[:page], per_page: params[:per_page])
    render action: :revision_list
  end

  def details
    if @user
      recent_time = params[:forever].to_i == 1 ? Time.now - 10.years : Time.now - 3.months
      only_ta_projects = params[:format] == 'xml'

      @chats = only_ta_projects ? ta_chats(@user, recent_time) : chats(@user, recent_time)

      review_chats = []
      managed_works = @user.managed_works.where('(managed_works.active = ?) AND (managed_works.owner_type=?) AND ((managed_works.updated_at >= ?) OR (managed_works.translation_status != ?))', MANAGED_WORK_ACTIVE, 'RevisionLanguage', recent_time, MANAGED_WORK_COMPLETE).to_a
      managed_works.reject! { |x| x.owner&.revision&.cms_request&.block_in_ta_tool? }

      logger.info '--------- loading from managed works -------------'
      managed_works.each do |managed_work|
        selected_bid = managed_work.owner.selected_bid
        if selected_bid && (!only_ta_projects || managed_work.owner.revision.kind == TA_PROJECT) && !review_chats.include?(selected_bid.chat)
          @chats << selected_bid.chat
        end
      end
      logger.info '--------- DONE -------------'
    end
    respond_to do |format|
      format.html
      format.xml
    end
  end

  private

  def verify_ownership
    if @user[:type] != 'Translator'
      set_err('Only translators can access here')
      false
    end
  end

  def open_website_translation_work_filtered(limit)
    @header = 'Open work'
    added_list_types = []
    res = @user.open_website_translation_work(false, limit).collect do |cms_request|
      website_list_type = "#{cms_request.website.name}-#{cms_request.list_type}"
      already_listed = cms_request.list_type && added_list_types.include?(website_list_type)
      added_list_types << website_list_type if cms_request.list_type && !already_listed
      [cms_request, !already_listed]
    end
    res
  end

  def ta_chats(user, recent_time)
    chats = user.chats.joins(:revision).
            where(
              '(revisions.kind=?) AND (revisions.release_date IS NULL OR (revisions.release_date >= ?))',
              TA_PROJECT, recent_time
            ).
            limit(user.ta_limit).
            order('chats.id DESC').to_a

    forced_to_display_on_ta = user.chats.joins(:revision).where('revisions.kind=? AND revisions.force_display_on_ta = true', TA_PROJECT)

    forced_to_display_on_ta.each do |c|
      chats << c unless chats.select { |x| x.id == c.id }.present?
    end

    block_new_requests_in_ta!(chats)
    chats
  end

  def block_new_requests_in_ta!(chats)
    chats.reject! { |ch| ch.revision&.cms_request&.block_in_ta_tool? }
  end

  def chats(user, recent_time)
    user.chats.joins(:revision).where('(revisions.release_date IS NULL OR (revisions.release_date >= ?))', recent_time).to_a
  end
end
