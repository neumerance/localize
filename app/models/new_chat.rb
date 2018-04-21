class NewChat
  attr_reader :body, :bid_amount, :bid_currency_id, :status
  def initialize(status, body = '', bid_amount = 0, bid_currency_id = 0)
    @status = status
    @body = body
    @bid_amount = bid_amount
    @bid_currency_id = bid_currency_id
  end
end
