class ApiError

  def initialize(code, message, title = '')
    @code = code
    @message = message
    @title = title
  end

  def error
    {
      code: @code,
      message: @message
    }
  end

  def json_error
    {
      errors: [
        {
          status: @code,
          title: @title,
          message: @message
        }
      ]
    }.to_json
  end
end
