class Admin < Supporter
  def users_to_switch
    User.all
  end

  def email
    if on_vacation?
      'hello@icanlocalize.com'
    else
      self['email']
    end
  end
end
