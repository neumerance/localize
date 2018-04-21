require 'rest-client'
class ApiResponder

  class << self

    def notify_tp_issue_closed(issue)
      RestClient.get issue.tp_callback_url
    end

  end

end
