module App
  module SetupNavigation
    def setup_navigation
      # don't do this for AJAX or XML requests
      return if request.xhr? || params[:format] == 'xml'
      return unless @user

      controller = params[:controller]
      action = params[:action]
      id = params[:id].to_i

      @top_bar, @bottom_bar = NavigationBuilder.new(controller, action, id, @user).build_navigation
    end
  end
end
