class ClientController < ApplicationController

  prepend_before_action :setup_user
  before_action :verify_ownership
  before_action :create_reminders_list
  before_action :setup_help
  before_action :set_client_startup_options, only: :getting_started

  layout :determine_layout

  def index
    @header = _('Your Projects Summary')
    @name_filter = params[:project_name]
    @name_filter = '' if @name_filter.nil?

    @websites = @user.websites.where('websites.name LIKE ?', "%#{@name_filter}%").page(1).per(PER_PAGE_SUMMARY)

    @websites_message = if @websites.total_pages > 1
                          _('Recent %d of CMS translation projects') % [PER_PAGE_SUMMARY] +
                            "&nbsp;&nbsp;&nbsp;<a href=\"#{url_for(controller: '/wpml/websites', action: :index)}\">" + _('Summary of all CMS translation projects') + '</a>'
                        else
                          _('Showing all your CMS translation projects')
                        end

    @revisions = @user.bidding_projects.joins(:project).
                 where('revisions.cms_request_id IS NULL AND projects.name LIKE ?', "%#{@name_filter}%").
                 order('revisions.id DESC').page(1).per(PER_PAGE_SUMMARY)
    @projects = @revisions.map(&:project).uniq

    @project_message = if @revisions.total_pages > 1
                         _('Recent %d of bidding projects') % [PER_PAGE_SUMMARY] +
                           "&nbsp;&nbsp;&nbsp;<a href=\"#{url_for(controller: :projects, action: :index)}\">" + _('Older bidding projects') + '</a>' \
                                                  "&nbsp;&nbsp;&nbsp;<a href=\"#{url_for(controller: :projects, action: :summary)}\">" + _('Summary of all bidding projects') + '</a>'
                       else
                         _('Showing all your bidding website translation projects')
                       end

    @web_messages = if @name_filter.blank?
                      @user.web_messages.order('web_messages.id DESC').page(1).per(PER_PAGE_SUMMARY)
                    else
                      @user.web_messages.where('web_messages.name LIKE ?', "%#{@name_filter}%").order('web_messages.id DESC').page(1).per(PER_PAGE_SUMMARY)
                    end

    @web_messages_message = if @web_messages.total_pages > 1
                              _('Recent %d of instant translation projects') % [PER_PAGE_SUMMARY] +
                                "&nbsp;&nbsp;&nbsp;<a href=\"#{url_for(controller: :web_messages, action: :index)}\">" + _('Older instant translation projects') + '</a>'
                            else
                              _('Showing all your instant translation projects')
                            end

    @text_resources = @user.text_resources.
                      where('text_resources.name LIKE ?', "%#{@name_filter}%").
                      order('text_resources.id DESC').page(1).per(PER_PAGE_SUMMARY)
    @text_resources_message = if @text_resources.total_pages > 1
                                _('Recent %d software localization projects') % [PER_PAGE_SUMMARY] +
                                  "&nbsp;&nbsp;&nbsp;<a href=\"#{url_for(controller: :text_resources, action: :index, anchor: 'project_list')}\">" + _('Older software localization projects') + '</a>'
                              else
                                _('Showing all your software localization projects')
                              end

    @arbitrations = Kaminari.paginate_array(@user.open_arbitrations("LIMIT #{PER_PAGE_SUMMARY}")).page(params[:page]).per(params[:per_page])
    @your_arbitrations_message = if @arbitrations.length
                                   _('Recent %d of %d arbitrations') % [PER_PAGE_SUMMARY, @arbitrations.count] +
                                     "&nbsp;&nbsp;&nbsp;<a href=\"#{url_for(controller: :arbitrations, action: :index)}\">" + _('Older arbitrations') + '</a>' \
                                     "&nbsp;&nbsp;&nbsp;<a href=\"#{url_for(controller: :arbitrations, action: :summary)}\">" + _('Summary of all arbitrations') + '</a>'
                                 else
                                   _('Showing all your arbitrations')
                                 end

    account = @user.find_or_create_account(DEFAULT_CURRENCY_ID)
    expenses, _, @pending_web_messages = account.pending_total_expenses
    @unfunded_web_messages = @user.unfunded_web_messages
    @missing_amount = expenses - account.balance

    respond_to do |format|
      format.html
      format.xml
    end
  end

  def getting_started
    unless @user.can_create_projects?
      set_err("can't do this")
      return
    end

    if @user.next_operation

      if params[:ignore_next].blank?
        if @user.next_operation.starts_with?('Sisulizer:')
          version_idx = @user.next_operation['Sisulizer:'.length..-1]
          begin
            version = ::Version.find(version_idx)
          rescue
            version = nil
          end

          if version && !version.revision
            redirect_to(controller: :projects, action: :continue_sisulizer, version_id: version.id)
            return
          end
        end
      end

      # if we're still here, it means we don't know what to do with this
      @user.update_attributes(next_operation: nil)
    end

    @header = _('What do you need to translate?')

    render action: :getting_started_new
  end

  def getting_started1
    todo = params[:todo]
    if todo == 'website_translation'
      @header = _('How is your website built?')
      @options = [['drupal', 'Using <b>Drupal</b> CMS'], ['wordpress', 'Using <b>WordPress</b>'],
                  ['html', 'With <b>static HTML</b> files']]
      @next_action = :getting_started2
      @back = :getting_started
    elsif todo == 'text_translation'
      @header = _('What kind of text do you need to translate?')
      @options = [['resource_translations', 'Software localization', 'iPhone, Delphi, Java, PHP and other types of application.', "#{INSTANT_TRANSLATION_COST_PER_WORD * TOP_CLIENT_DISCOUNT} - #{INSTANT_TRANSLATION_COST_PER_WORD} USD / word"],
                  ['instant_translation', 'Short text', 'Instant translation projects are good for getting quick translations. The text must be self-explanatory as communication with the translator is not possible for this kind of projects.', 'varies according to language'],
                  ['bidding_project', 'General purpose document translation', 'This type of project is good for any kind of translation. You will be able to upload the document or text that needs to be translated and select the translator who will do the translation.', 'translators will bid'],
                  ['sisulizer_project', 'Sisulizer project', 'Upload your Sisulizer .slp project and translators will apply to translate it.', 'translators will bid'],
                  ['support_center', 'Translate support emails.', 'You will be able to set up automatic instant translation for customer support between languages that you select.', "#{INSTANT_TRANSLATION_COST_PER_WORD} USD / word"]]
      @next_action = :getting_started3
      @back = :getting_started
    elsif todo == 'hm_translation'
      redirect_to action: :translate_with_ta, what: 'Help and Manual project'
      return
    elsif todo == 'support_center'
      redirect_to controller: :web_supports, action: :new
      return
    else
      flash[:notice] = 'Please select one of the options'
      redirect_to action: :getting_started
      return
    end

    render action: :getting_started
  end

  def getting_started2
    todo = params[:todo]
    if todo == 'drupal'
      redirect_to action: :getting_started4, cms_kind: WEBSITE_DRUPAL
    elsif todo == 'wordpress'
      redirect_to action: :getting_started4, cms_kind: WEBSITE_WORDPRESS
    elsif todo == 'html'
      redirect_to action: :translate_with_ta, what: _('static HTML website')
    else
      flash[:notice] = 'Please select one of the options'
      redirect_to action: :getting_started
      return
    end
  end

  def getting_started3
    todo = params[:todo]
    if todo == 'resource_translations'
      redirect_to controller: :text_resources, action: :index
    elsif todo == 'instant_translation'
      redirect_to controller: :web_messages, action: :new
    elsif todo == 'bidding_project'
      redirect_to controller: :projects, action: :new
    elsif todo == 'sisulizer_project'
      redirect_to controller: :projects, action: :new_sisulizer
    elsif todo == 'support_center'
      redirect_to controller: :web_supports, action: :new
    else
      flash[:notice] = 'Please select one of the options'
      redirect_to action: :getting_started
    end
  end

  def translate_with_ta
    @what = params[:what] || _('static HTML website')
    @header = _('Translate a %s') % @what
  end

  def getting_started4
    @cms_kind = params[:cms_kind].to_i
    if WEBSITE_DESCRIPTION.key?(@cms_kind)
      cms = WEBSITE_DESCRIPTION[@cms_kind]
    else
      redirect_to action: :index
      return
    end
    @header = _("#{cms} translation")
  end

  def details
    if @user
      only_ta_projects = params[:format] == 'xml'

      # get all user projects
      @projects = if only_ta_projects
                    @user.projects.includes(:revisions).where('projects.kind=?', TA_PROJECT).limit(@user.ta_limit).order('id DESC')
                  else
                    @user.projects.includes(:revisions)
                  end

      @projects = @projects.to_a

      forced_to_display_on_ta = @user.projects.joins(:revisions).where('projects.kind=? AND revisions.force_display_on_ta = true', TA_PROJECT)

      forced_to_display_on_ta.each do |p|
        @projects << p unless @projects.select { |x| x.id == p.id }.present?
      end

      # track all user projects and siblings, if they're not tracked already
      if @user_session.tracked != 1
        logger.info '------------ automatically adding session tracks for all projects'
        @projects.each { |project| project.track_with_siblings(@user_session) }
        @user_session.update_attributes(tracked: 1)
        logger.info '------------ done with tracks'
      end
    end
    respond_to do |format|
      format.html
      format.xml
    end
  end

  def pending_cms_requests
    filter = params[:filter]
    if filter == 'pending_TAS'
      conditions = CMS_REQUEST_WAITING_FOR_TAS
    elsif filter == 'sent'
      conditions = [CMS_REQUEST_RELEASED_TO_TRANSLATORS]
    elsif filter == 'pickup'
      conditions = [CMS_REQUEST_TRANSLATED]
    elsif filter == 'all'
      conditions = nil
    end

    @pending_cms_requests = if conditions
                              @user.cms_requests.where('cms_requests.status IN (?)', conditions)
                            else
                              @user.cms_requests
                            end
    respond_to do |format|
      format.html
      format.xml
    end
  end

  def sandbox_jobs
    if Rails.env.sandbox? || Rails.env.development?
      if request.post?
        @job = CmsRequest.find_by_id(params[:job_id])
        if @job
          xliff = @job.xliffs.last
          if xliff
            xliff.translated = true
            xliff.save!
            @job.status = 6
            @job.save!
          end
        end
      end
      query = "Select c.* from users as u
                inner join websites as w on u.id = w.client_id
                inner join cms_requests as c on w.id = c.website_id
                where u.id = #{@user.id} order by c.id desc"
      @jobs = CmsRequest.find_by_sql(query)
    else
      redirect_to '/'
    end
  end

  private

  def verify_ownership
    unless %w(Client Alias).include? @user[:type]
      set_err('Only clients can access here')
      false
    end
  end

  def set_client_startup_options
    @options =
      [
        [_('Websites'), [[_('WordPress sites'), { controller: :client, action: :getting_started4, cms_kind: WEBSITE_WORDPRESS }, _('send content to translation directly from WordPress.')],
                         [_('Sites built directly with HTML files'), { controller: :client, action: :translate_with_ta }, _('use our translation software to build the translated HTML pages.')]]],
        [_('Software'), [[_('iPhone, Android, PO/POT and other resource files'), { controller: :text_resources, action: :new }, _("upload your app's resource files and download the completed translations.")],
                         [_('Sisulizer projects'), { controller: :projects, action: :new_sisulizer }, _("upload your Sisulizer project and we'll translate it.")]]],
        [_('Documents and Plain-Texts'), [[_('Office documents'), { controller: :projects, action: :new }, _('upload any kind of document for translation.')],
                                          [_('Fast text translation'), { controller: :web_messages, action: :new }, _('paste your text, get some coffee and pick up the completed translations.')],
                                          [_('Help and Manual projects'), { controller: :client, action: :translate_with_ta, what: 'Help and Manual project' }, _('download our translation software and create translated H&M projects.')]]]
      ]
  end

end
