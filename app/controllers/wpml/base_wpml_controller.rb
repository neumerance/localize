class Wpml::BaseWpmlController < ApplicationController
  # Custom exceptions
  include Error

  # Reads the session. If user us not logged in, require login. If user is
  # logged in, set @user and perform other verifications/adjustments.
  # Setup user aldo handles login via website accesskey, which is required for
  # WPML 3.8 and older compatibility (it opens ICL pages in IFrames)
  prepend_before_action :setup_user
  before_action :restrict_user_types
  before_action :create_reminders_list

  layout :select_layout

  def set_website(website_id)
    # The following line throws an ActiveRecord::RecordNotFound when the
    # website ID is not found (see icldev-2684). This is not the expected
    # behavior from Rails. The begin/rescue is only a workaround to ensure a 404
    # error page is displayed.
    @website = Website.find(website_id)
  rescue ActiveRecord::RecordNotFound
    raise ActionController::RoutingError, 'Not Found'
  end

  private

  def select_layout
    return 'application' if request.format.json?
    if params[:compact] == '1'
      'compact'
    else
      'standard'
    end
  end

  def restrict_user_types
    # We could use App::Redirects#redirect_after_login but it doesn't work
    # with namespaced controllers.
    case @user
    when Client, Alias, Supporter, Admin
      # Can access
      true
    when Translator
      redirect_to '/translator',
                  notice: 'You do not have permission to access this page.'
    else
      redirect_to request.referer.present? ? request.referer : '/',
                  notice: 'You do not have permission to access this page.'
    end
  end
end
