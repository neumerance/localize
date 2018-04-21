class ResourceLanguagesController < ApplicationController
  prepend_before_action :setup_user
  layout :determine_layout

  def unassign_translator
    return unless @user.has_supporter_privileges?

    if ResourceLanguage.find(params[:id]).unassign_translator
      render html: "<span style='font-weight:bold; color:red;'>(Removed)</span>"
    else
      render html: "<span style='font-weight:bold; color:red;'>Error! not removed!</span>"
    end
  end

  def mass_unassign
    return unless @user.has_supporter_privileges?

    ResourceLanguage.find(params[:ids]).each(&:unassign_translator)
    render html: "<span style='font-weight:bold; color:red;'>(Removed)</span>"
  end
end
