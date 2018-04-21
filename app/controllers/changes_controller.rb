class ChangesController < ApplicationController

  before_action :setup_only_session
  layout :determine_layout

  def track_project
    id = params[:id]
    project = Project.find(id)
    track = ProjectTrack.new(resource_id: id)
    report_add_track(project.add_track(track, @user_session))
  end

  def track_revision
    id = params[:id]
    revision = Revision.find(id)
    track = RevisionTrack.new(resource_id: id)
    report_add_track(revision.add_track(track, @user_session))
  end

  def track_chat
    id = params[:id]
    chat = Chat.find(id)
    track = ChatTrack.new(resource_id: id)
    report_add_track(chat.add_track(track, @user_session))
  end

  def changenum
    @counter = if @user_session
                 @user_session.counter
               else
                 -1
               end

    respond_to do |format|
      format.html
      format.xml
    end
  end

  def get_serial_num
    @serial_num = SerialNumber.create!
    respond_to do |format|
      format.html
      format.xml
    end
  end

  private

  def report_add_track(added_ok)
    @status = if added_ok
                'OK'
              else
                'Not added'
              end
    respond_to do |format|
      format.html
      format.xml { render action: :track_added }
    end
  end

  def setup_only_session
    session_num = params['session']
    @user_session = UserSession.where(session_num: session_num).first
    ok = false
    @status = 'not logged in'
    if @user_session
      if !@user_session.timed_out
        @user_session.update_chgtime
        @status = 'logged in'
        ok = true
      else
        @user_session.destroy
      end
    end

    unless ok
      respond_to do |format|
        @err_code = NOT_LOGGED_IN_ERROR
        format.xml { render action: :blank }
      end
      return false
    end
  end

end
