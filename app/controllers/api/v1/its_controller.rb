class Api::V1::ItsController < Api::V1::ApiController
  before_action :set_it, except: [:index]

  def index
    render json: @current_user.instant_translations.to_json
  end

  def show
    response = @it.as_json
    response['is_owned_by_current_translator'] = (@it.translator == @current_user)
    render json: response
  end

  def take
    render json: @it.take_for_translation(@current_user).to_json
  end

  def release
    render json: @it.release_from_translation(@current_user).to_json
  end

  def save
    @err = @it.api_save_it(params[:translations], @current_user)
    if @err
      render json: @err
    else
      render json: { code: 200, status: 'OK' }
    end
  end

  private

  def set_it
    @it = WebMessage.find_by_id(params[:id])
    @it = nil if @it.present? && !@it.translator.nil? && @it.translator != @current_user
    raise ActionController::RoutingError, 'Not Found' if @it.nil?
  end

end
