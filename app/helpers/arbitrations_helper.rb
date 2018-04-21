module ArbitrationsHelper
  def last_message_in_arbitration(arbitration)
    if arbitration.status == ARBITRATION_CLOSED
      ''
    elsif arbitration.messages.count == 0
      'no messages yet'
    else
      last_message = arbitration.messages[-1]
      user_link(last_message.user) + ', ' + disp_time(last_message.chgtime)
    end
  end
end
