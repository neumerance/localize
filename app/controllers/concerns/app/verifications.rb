module App
  module Verifications
    def verify_client
      unless @user && @user.has_client_privileges?
        set_err("You can't access this page")
        false
      end
    end

    private

    def verify_supporter
      unless @user.has_supporter_privileges?
        set_err('You do not have permission to do that')
        false
      end
    end

    def verify_alias_can_create
      if @user && @user.alias? && !@user.can_create_projects?
        set_err("You can't do that.")
        false
      end
    end
  end
end
