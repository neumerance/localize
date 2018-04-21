module App
  module SetupHelp
    def setup_help
      # don't do this for AJAX or XML requests
      return if request.xhr? || params[:format] == 'xml'

      # create the user status mask
      help_mask = 0
      if @user
        if @user[:type] == 'Translator'
          help_mask |= HELP_PLACEMENT_TRANSLATOR
          help_mask |= HELP_PLACEMENT_UNQUALIFIED_TRANSLATOR if @user.userstatus != USER_STATUS_QUALIFIED
        elsif @user[:type] == 'Client'
          help_mask |= HELP_PLACEMENT_CLIENT
          help_mask |= HELP_PLACEMENT_CLIENT_WITHOUT_PROJECT if @user.projects.count == 0
        end
        help_mask |= HELP_PLACEMENT_UNVERIFIED_IDENTITY unless @user.verified?
      end

      @help_placements = HelpPlacement.includes(:help_group, :help_topic).where(['(help_placements.controller=?) AND
                  ((help_placements.action IS NULL) OR (help_placements.action=?)) AND
                  ((help_placements.user_match_mask & (help_placements.user_match ^ ?)) = 0)', params[:controller], params[:action], help_mask])
    end
  end
end
