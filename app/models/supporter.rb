class Supporter < NormalUser
  has_many :arbitrations
  has_many :error_reports
  has_many :support_tickets
  has_many :contacts

  def users_to_switch
    Client.all + Translator.all
  end

  def email
    if on_vacation?
      'hello@icanlocalize.com'
    else
      self['email']
    end
  end

  def can_view?(_p)
    true
  end

  def can_edit?(_p)
    true
  end

  def can_modify?(_p)
    true
  end

  def can_deposit?
    false
  end

  def can_pay?
    true
  end

  def can_view_finance?
    true
  end

  def verified?
    true
  end

  def self.new_account(name, email, password)
    s = Supporter.new
    s.type = 'Admin'
    s.userstatus = 1
    s.fname = name
    s.lname = 'Supporter'
    s.email = email
    s.nickname = "#{name}.supporter"
    s.password = password
    s.save!
  end
end
