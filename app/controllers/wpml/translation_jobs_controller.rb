class Wpml::TranslationJobsController < Wpml::BaseWpmlController
  include ::ReuseHelpers

  # set_website is implemented at Wpml::BaseWpmlController
  before_action { set_website(params[:website_id]) }
  # BaseWpmlController handles authentication, including website accesskey-based
  # authentication required for WPML <3.9 compatibility.
  before_action :authorize_client
  before_action :set_language_pair, except: [:index, :invite_translator]

  # GET /wpml/websites/:website_id/translation_jobs
  # Pending translation jobs
  def index
    @header = "Pending Translation Jobs for #{@website.name}"
    @total_amount_without_tax = @website.total_amount
    @client_account_balance = @website.client.find_or_create_account(DEFAULT_CURRENCY_ID).balance
    @missing_amount_without_tax = @total_amount_without_tax - @client_account_balance
    # projects_to_reuse is implemented in ReuseHelpers
    @projects_to_reuse = projects_to_reuse
    # Not all cms_requests are processed, we can use only processed ones
    # (unprocessed don't have a word count yet or their word count may still be
    # updated)
    @total_cms_requests = @website.all_pending_cms_requests
    @processed_cms_requests = @website.processed_pending_cms_requests
  end

  # PUT/PATCH /wpml/websites/:website_id/translation_jobs/:id (WTO id)
  def update
    if language_pair_params[:automatic_translator_assignment] == 'true'
      @language_pair.enable_automatic_translator_assignment!
    elsif language_pair_params[:automatic_translator_assignment] == 'false'
      @language_pair.disable_automatic_translator_assignment!
    end
  end

  # PUT/PATCH /wpml/websites/:website_id/translation_jobs/:id/toggle_review (WTO id)
  def toggle_review
    params[:review_enabled] == 'true' ? @language_pair.enable_review_for_pending_jobs : @language_pair.disable_review_for_pending_jobs
  end

  def invite_translator; end

  private

  def set_language_pair
    # @language_pair is an WebsiteTranslationOffer
    @language_pair = WebsiteTranslationOffer.find(params[:id])
  end

  def authorize_client
    # The #can_view? method is implemented in Client, Alias and Supporter models
    raise Error::NotAuthorizedError unless @user.can_view?(@website)
  end

  # Only allow a trusted parameter "white list" through.
  def language_pair_params
    params.require(:website_translation_offer).permit(:automatic_translator_assignment)
  end
end
