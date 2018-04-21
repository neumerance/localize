class NewslettersController < ApplicationController
  prepend_before_action :setup_user_optional, except: [:feed, :sitemap]
  layout :determine_layout, except: [:feed, :sitemap]
  before_action :setup_item, except: [:index, :new, :create, :feed, :sitemap]
  before_action :verify_admin, except: [:index, :show, :feed, :sitemap]

  def index
    if @user && @user.has_admin_privileges?
      @header = 'Browse news items'
      @newsletters = Newsletter.all
    else
      @header = 'ICanLocalize newsletter archive'
      mask = NEWSLETTER_SENT | NEWSLETTER_PUBLIC
      @newsletters = Newsletter.where('(flags & ?) = ?', mask, mask).order('ID DESC').limit(10)
      render action: :list
    end
  end

  def feed
    mask = NEWSLETTER_SENT | NEWSLETTER_PUBLIC
    @newsletters = Newsletter.where('(flags & ?) = ?', mask, mask).order('ID DESC').limit(10)
    @feeds_url = "#{EMAIL_LINK_HOST}/newsletters/rss.xml"
  end

  def sitemap
    mask = NEWSLETTER_SENT | NEWSLETTER_PUBLIC
    @newsletters = Newsletter.order('ID DESC').where('(flags & ?) = ?', mask, mask)
    @feeds_url = "#{EMAIL_LINK_HOST}/newsletters/rss.xml"
  end

  def new
    @newsletter = Newsletter.new(flags: 0)
    @header = 'Create a new news item'
    @urlto = { action: :create }
    @methodto = :post
    render action: :edit
  end

  def show
    if @user && @user.has_admin_privileges?
      @header = 'Newsletter preview'
    else
      @header = @newsletter.subject
      render action: :display
    end

  end

  def plain
    @header = 'Plain text preview'
  end

  def edit
    @newsletter = Newsletter.find(params[:id])
    @header = 'Edit news item'
    @urlto = { action: :update, id: @newsletter.id }
    @methodto = :put
  end

  def create
    flags = 0
    params[:flags].keys.each { |param| flags |= param.to_i } if params[:flags]
    @newsletter = Newsletter.new(params[:newsletter])
    @newsletter.flags = flags
    @newsletter.chgtime = Time.now

    if @newsletter.save
      redirect_to action: :show, id: @newsletter.id
    else
      @header = 'Create a new news item'
      @urlto = { action: :create }
      @methodto = :post
      render action: :edit
    end
  end

  def update
    flags = 0
    params[:flags].keys.each { |param| flags |= param.to_i } if params[:flags]
    pars = {}
    pars = params[:newsletter].each { |k, v| pars[k] = v }
    pars['flags'] = flags
    pars['chgtime'] = Time.now
    if @newsletter.update_attributes(pars)
      # invalidate all the cache instances
      @newsletter.text_results.delete_all

      redirect_to action: :show, id: @newsletter.id
    else
      @header = 'Edit news item'
      @urlto = { action: :update, id: @newsletter.id }
      @methodto = :put
      render action: :edit
    end
  end

  def delete
    @newsletter.destroy
    redirect_to action: :index
  end

  def test
    emails = Array.new
    emails += Newsletter::DEFAULT_TEST_EMAILS

    e = params[:receipt][:email]
    emails << params[:receipt][:email] if e != '@icanlocalize.com' && !e.empty?
    sent = []

    emails.uniq.each do |email|
      user = User.find_by_email(email)
      next unless user
      logger.info "Testing newsletter to #{user.email}"
      ReminderMailer.newsletter(user, @newsletter).deliver_now
      sent << user.email
    end

    flash[:notice] = "Sent to #{sent.join(', ')}"
    redirect_to action: :show
  end

  def count_users
    @header = _('Users to receive this newsletter')
    begin
      @users = @newsletter.target_users
    rescue StandardError => exc
      flash[:notice] = _("Error in SQL query:\n\n#{exc.message}")
      redirect_to(action: :show)
    end
  end

  private

  def collect_flags(flag_params)
    res = 0
    flag_params.each { |_param| res |= params.to_i }
    res
  end

  def setup_item
    @newsletter = Newsletter.find(params[:id])
  end

  def verify_admin
    unless @user && @user.has_admin_privileges?
      set_err('You cannot visit this page')
      false
    end
  end

  def setup_user_optional
    setup_user(false)
  end

end
