module Trackable

  def update_track(tracks)
    if tracks
      for track in tracks
        begin
          if track.user_session
            track.user_session.counter += 1
            track.user_session.save
          else
            track.destroy
          end
        rescue
        end
      end
    end
  end

  # add a track to the current user's session
  def add_track(track, user_session)
    if user_session
      other_track = SessionTrack.where('user_session_id=? AND type=? AND resource_id=?', user_session.id, track[:type], track.resource_id).first
      return false if other_track
      track.user_session = user_session
      unless track.save
        # this indicates that a similar track already exists
        return false
      end
      true
    else
      false
    end
  end

  def update_track_by_user(user_ids)
    UserSession.where('user_id IN (?)', user_ids).each do |session|
      begin
        if session.timed_out
          session.destroy
        else
          session.update_attributes(counter: session.counter + 1)
        end
      rescue
      end
    end
  end

end
