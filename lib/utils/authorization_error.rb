class AuthorizationError < JSONError
  def initialize(model, id, accesskey)
    @code = AUTHORIZATION_ERROR
    @message = "Can't access #{model} with id: #{id}; accesskey: #{accesskey}"
  end
end
