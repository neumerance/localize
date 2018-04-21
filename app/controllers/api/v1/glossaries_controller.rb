class Api::V1::GlossariesController < Api::V1::ApiController

  before_action :set_client

  def index
    render json: glossary_items(@client, @cms_request)
  end

  def create
    render json: GlossaryTerm.webta_create(params, @cms_request)
  end

  def update
    render json: GlossaryTerm.webta_update(params, @cms_request, @current_user)
  end

  private

  def glossary_items(client, cms_request)
    render json: {} && return unless cms_request
    target_language = cms_request.cms_target_language.language

    glossaries = client.glossary_terms.
                 joins(:glossary_translations).
                 where('glossary_terms.language_id' => cms_request.language_id).
                 where('glossary_translations.language_id' => target_language.id)

    glossaries.map { |glossary| glossary.to_json(target_language) }
  end

  def set_client
    render status: 200 && return if params[:cms_request_id].to_i == 0
    @cms_request = CmsRequest.find(params[:cms_request_id])
    @client = @cms_request.try(:website).try(:client)
    raise ActionController::RoutingError, 'Not Found' unless permitted_request?
  end

  def permitted_request?
    return true if Translation::SuperTranslator.user_exists?(@current_user)

    @cms_request.present? && @client.present? &&
      (@current_user == @cms_request.cms_target_language.translator || @current_user == @cms_request.reviewer)
  end
end
