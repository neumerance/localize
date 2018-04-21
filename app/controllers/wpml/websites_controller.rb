class Wpml::WebsitesController < Wpml::BaseWpmlController

  # Callbacks for web views
  # set_website is implemented at Wpml::BaseWpmlController
  before_action except: [:index, :token, :migrated, :api_token] { set_website(params[:id]) }
  # BaseWpmlController handles authentication, including website accesskey-based
  # authentication required for WPML <3.9 compatibility.
  before_action :authorize_client, except: [:index, :token, :migrated, :api_token]

  # Callbacks for API
  skip_before_action :setup_user, :restrict_user_types, only: [:token, :migrated]
  before_action :set_website_from_accesskey, except: [:index, :show, :update,
                                                      :edit_website_inplace,
                                                      :edit_tm_inplace,
                                                      :toggle_review, :api_token,
                                                      :client_can_pay_any_language_pairs,
                                                      :assign_reviewer, :create_testimonial]

  ############################ Web view actions ################################

  # GET /wpml/websites
  def index
    if @user.class.in?([Admin, Supporter])
      # Supporters have their own website projects index page
      redirect_to controller: '/supporter', action: 'cms_projects'
      return
    end

    @header = 'WPML Websites'
    # For Alias users, Alias#websites includes only the websites they are
    # allowed to access.
    @websites = @user.websites

    case @websites.size
    when 0
      # When the API key is inserted into WPML, TP sends a request to the ICL
      # API which immediately creates a Website record. If a client has no
      # Websites, it means he did not insert the API key into WPML.
      render :api_key_not_inserted
    when 1
      # If the user only has one website, there is no point in displaying the
      # list of websites. Redirect to that website's page.
      redirect_to action: 'show', id: @websites.first.id
    else
      render :index
    end
  end

  # GET /wpml/websites/1
  def show;
    @header = @website.name
    # check for problematic cms requests
    @error_cms_requests_length = @website.error_cms_requests.count
  end

  # PUT/PATCH /wpml/websites/1
  def update
    @website.update(website_params)
    # Save the selected category and don't refresh the page
    head :no_content
  end

  # Inplace editing of website name, description, subject and URL
  def edit_website_inplace
    req = params[:req]
    if req == 'show'  # Display the form for inplace editing
      @editing = true
    elsif req.nil?    # Save changes
      @website.assign_attributes(params[:website])
      if @website.valid?
        @website.save
      else
        @website.reload
      end
    end
  end

  # Inplace editing of translation memory settings
  def edit_tm_inplace
    req = params[:req]
    if req == 'show'
      @editing = true
    elsif req.nil?
      @website.tm_use_mode = params[:tm_use_mode].to_i
      @website.tm_use_threshold = params[:tm_use_threshold].to_i
      @website.save
    end
    # If req == 'hide', do nothing
    @website.reload
  end

  # PUT/PATCH /wpml/websites/:website_id/:id/toggle_review (second id is the WTO id)
  #
  # Enable or disable review by language pair. This only affects the
  # default/initial review status displayed in the "Pending Translation Jobs"
  # page. It does not enable/disable review for any existing translation jobs.
  def toggle_review
    # language_pair is an WebsiteTranslationOffer
    language_pair = WebsiteTranslationOffer.find(params[:website_translation_offer_id])
    params[:review_enabled] == 'true' ? language_pair.enable_review_by_default : language_pair.disable_review_by_default
    head :no_content
  end

  # Used for supporters to assign reviewers for *manual translator assignment*
  # language pairs.
  def assign_reviewer
    language_pair = WebsiteTranslationOffer.find(params[:website_translation_offer_id])
    reviewer = Translator.where(nickname: params[:nickname]).take

    unless reviewer.present?
      flash[:notice] = 'Could not find a translator by that nickname.' if
      redirect_to :back
      return
    end

    begin
      language_pair.assign_reviewer_to_managed_work(reviewer)
      flash[:notice] = 'Reviewer assigned.'
    rescue StandardError => e
      flash[:notice] = e.message
    end
    redirect_to :back
  end

  def api_token; end

  ############################### API actions ##################################

  # GET /websites/:id/token.json
  # Used to convert an accesskey/website_id pair to client.api_key
  def token
    render json: { api_token: @website.client.api_key }.to_json
  end

  # POST /websites/:id/migrated
  # Used as callback url for WPML to signal that a website was migrated to the latest WPML version
  def migrated
    @website.update_attributes(api_version: '2.0')
    render json: {}.to_json
  end

  def client_can_pay_any_language_pairs
    render json: { enable_pay_button: @website.client_can_pay_any_language_pair? }
  end

  def create_testimonial
    website = Website.find_by_id params[:id]
    website.create_testimonial(params)
    flash[:notice] = 'Testimonial has been sent'
    redirect_to :back
  rescue => e
    flash[:notice] = e.message
    redirect_to :back
  end

  private

  ######################## Web view private methods ############################

  def authorize_client
    # The #can_view? method is implemented in Client, Alias and Supporter models
    raise Error::NotAuthorizedError unless @user.can_view?(@website)
  end

  def website_params
    params.require(:website).permit(:category_id, :accesskey)
  end

  ########################### API private methods ##############################

  def set_website_from_accesskey
    @website = Website.find_by_id params[:id]
    raise ActionController::RoutingError, 'Not Found' unless @website.present? && @website.accesskey == params[:accesskey]
  end
end
