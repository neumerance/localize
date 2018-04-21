class NotificationsController < ApplicationController

  prepend_before_action :setup_user
  before_action :setup_help
  layout :determine_layout

  def index
    @header = _('Notification preferences')
    current_notifications = @user.notifications
    notification_flags = if @user[:type] == 'Translator'
                           [NEWSLETTER_NOTIFICATION, DAILY_RELEVANT_PROJECTS_NOTIFICATION] # DAILY_ALL_PROJECTS_NOTIFICATION,	MONTHLY_STATEMENT_NOTIFICATION]
                         else
                           [NEWSLETTER_NOTIFICATION] # , MONTHLY_STATEMENT_NOTIFICATION]
                         end
    @notification_list = notification_flags.collect do |notification|
      [[notification, (current_notifications & notification) == notification], User::NOTIFICATION_TEXT[notification]]
    end
  end

  def update
    begin
      notification_list = make_dict(params[:notification])
    rescue
      notification_list = []
      logger.info('   ---> Cannot find notification list!')
    end
    new_mask = 0
    notification_list.each do |notification|
      new_mask |= notification
      logger.info "------------ Added #{notification} => #{new_mask}"
    end
    @user.update_attributes(notifications: new_mask)
    flash[:notice] = _('Your preferences have been updated')
    redirect_to action: :index
  end

end
