class Partner < NormalUser

  def verified?
    true
  end

  def can_view_finance?
    false
  end

end
