module App
  module UserAgent
    def detect_browser
      @browser = Browser.new(request.user_agent)
      @is_modern = @browser.modern?
    end
  end
end
