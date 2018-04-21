class PartnerController < ApplicationController
  prepend_before_action :setup_user
  before_action :verify_ownership
  before_action :create_reminders_list
  before_action :setup_help
  layout :determine_layout

  def index
    @header = _('Partner resources')
  end

  private

  def verify_ownership
    if @user[:type] != 'Partner'
      set_err('Only partners can access here')
      false
    end
  end

end
