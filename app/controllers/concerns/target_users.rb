module TargetUsers
  # find the target users selected for a message
  def get_target_users
    res = []
    max_idx = params['max_idx'].to_i
    (1..max_idx).each do |idx|
      param = "for_who#{idx}"
      next unless params[param]
      user_id = params[param].to_i
      begin
        user = User.find(user_id)
        res << user
      rescue
        # ignored
      end
    end

    res
  end

  # return all the users for which we can send a reply
  def collect_target_users(current_user, users_list, messages = nil)
    res = []
    users_list.each do |user|
      res << user if user && (user != current_user) && !res.include?(user)
    end

    if messages
      messages.each do |message|
        if (message.user.present? && message.user != current_user) &&
           message.user.userstatus != USER_STATUS_CLOSED &&
           !res.include?(message.user)
          res << message.user
        end
      end
    end

    res
  end
end
