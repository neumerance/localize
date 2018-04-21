class RemindersController < ApplicationController
  prepend_before_action :setup_user, only: [:index, :delete_selected, :destroy]
  layout :determine_layout, only: [:index, :destroy]
  before_action :setup_help

  def index
    @header = _('Your reminders')

    if params[:wid].blank?
      @reminders = @user.reminders.order('reminders.id DESC').all
    else
      begin
        website = Website.find(params[:wid].to_i)
      rescue
        set_err('not your website')
        return
      end
      if website.client != @user
        set_err('not your website')
        return
      end
      @reminders = website.reminders.where(normal_user_id: @user.id).order('reminders.id DESC')
    end

    logger.info "----------------REMINDERS: returning #{@reminders.length} reminders ------------------ "

    respond_to do |format|
      format.html
      format.xml
    end
  end

  def delete_selected
    begin
      delete_list = make_dict(params[:reminder])
    rescue
      delete_list = []
    end

    for reminder_id in delete_list
      begin
        reminder = Reminder.find(reminder_id)
      rescue
        reminder = nil
      end

      if reminder && (reminder.normal_user == @user) && !PROTECTED_EVENTS.include?(reminder.event)
        reminder.destroy
      end
    end

    respond_to do |format|
      format.html { redirect_to action: :index }
      format.xml
    end
  end

  def destroy
    @result = 'Cannot delete'
    @reminder_id = params[:id].to_i

    # verify that this reminder belongs to the user
    begin
      reminder = Reminder.find(@reminder_id)
    rescue
      @result = 'Reminder not found'
      return
    end

    if (reminder.normal_user_id != @user.id) || PROTECTED_EVENTS.include?(reminder.event)
      @result = 'Reminder protected'
      return
    end

    # delete the object itself
    Reminder.delete(@reminder_id)
    @result = 'Reminder deleted'

    # clean from the reminders list in the session
    @reminders = []

    if session[:show_reminders]
      @reminders = @user.reminders.where(session[:reminders_conditions]).order('reminders.id DESC')
      @update_reminders = true
      if @reminders.empty?
        @hide = true
        session[:reminders_conditions] = nil
        session[:show_reminders] = false
      end
    else
      @hide = true
    end

    respond_to do |format|
      format.html
      format.xml
      format.js
    end
  end

  def hide
    session[:hide_reminders] = true
    respond_to do |format|
      format.html { (request.referer.present? ? (redirect_to :back) : (render plain: '')) }
      format.js
    end
  end

  def unhide
    session[:hide_reminders] = nil
    respond_to do |format|
      format.html { (request.referer.present? ? (redirect_to :back) : (render plain: '')) }
      format.js
    end
  end

end
