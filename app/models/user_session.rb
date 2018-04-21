class UserSession < ApplicationRecord
  has_many :session_tracks
  belongs_to :user

  def self.logged_in(user_id)
    user_sessions = where(user_id: user_id)
    if user_sessions.nil?
      return false
    else
      user_sessions.each do |session|
        return true unless session.timed_out
      end
    end
    false
  end

  def destroy
    track_ids = []
    session_tracks.each { |track| track_ids << track.id }
    SessionTrack.where(id: track_ids).delete_all
    super
  end

  def update_chgtime
    update_attributes(login_time: Time.now)
  end

  def timed_out
    long_life ? ((Time.now - login_time) > TAS_TIMEOUT) : ((Time.now - login_time) > SESSION_TIMEOUT)
  end
end
