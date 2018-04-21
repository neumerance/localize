class InvalidParams < JSONError
  def initialize(model, attrs = nil)
    @code = INVALID_PARAMS
    @message = if attrs
                 "Invalid params for #{model} - expecting #{attrs.inspect}"
               else
                 "Expecting an hash for #{model}"
               end
  end
end
