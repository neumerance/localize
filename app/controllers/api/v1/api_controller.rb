class Api::V1::ApiController < ActionController::API

  rescue_from ActiveRecord::RecordNotFound, with: :handle_record_not_found

  before_action :authenticate_request, except: [:authenticate, :quote]

  @success = { code: 200, status: 'OK' }.to_json

  def authenticate
    command = AuthenticateUser.call(params[:email], params[:password], params[:token])
    if command.success?
      token, user = command.result
      render json: { auth_token: token, user: { id: user.id, nickname: user.nickname, is_supporter: user.has_supporter_privileges? } }
    else
      render json: { error: command.errors }, status: :unauthorized
    end
  rescue
    render json: { error: 'Not Authorized' }, status: 401
  end

  def quote
    # respond_to do |format|
    #   format.json { render :json => Api.new.quote(params[:file]) }
    # end
    # this is just a quick fix to make the test run, dont know the reason yet why some tests is failing when using the code above
    render json: Api.new.quote(params[:file])
  end

  def test_api_request
    render json: { all_ok: true }
  end

  def handle_record_not_found
    @err = ApiError.new(404, 'Not found')
    render json: @err.error
  end

  rescue_from ActionController::RoutingError, with: :not_found

  # def append_info_to_payload(payload)
  #   super
  #   payload[:ip] = remote_ip(request)
  #   payload[:user_type] = @current_user.present? ? @current_user.class.to_s : 'Anonymous'
  #   unless @exception.nil?
  #     payload[:exception_object] = @exception
  #     payload[:exception] = [@exception.class.to_s, @exception.message]
  #   end
  # end

  private

  # def remote_ip(request)
  #   request.headers['HTTP_X_REAL_IP'] || request.headers['HTTP_X_FORWARDED_FOR'] || request.remote_ip
  # end

  def authenticate_request
    @current_user = AuthorizeApiRequest.call(request.headers).result
    render json: { error: 'Not Authorized' }, status: 401 unless @current_user
  rescue
    render json: { error: 'Not Authorized' }, status: 401
  end

  def not_found
    render(status: 404) && return
  end

end
